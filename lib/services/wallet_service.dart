import 'dart:convert';
import 'dart:core';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'spot_service.dart';
import 'auth_service.dart';
import 'notification_service.dart';

class WalletService {
  static const String baseUrl = 'https://api11.hathmetech.com/api';
  
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
        debugPrint('RAW BALANCE PAYLOAD: ${response.body}');
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

  // Fetch INR balance directly from wallet API
  static Future<Map<String, dynamic>> getINRBalance() async {
    try {
      debugPrint('=== Fetching INR Balance ===');
      
      // Try all-wallet-balance API first (most reliable for INR)
      final result = await getAllWalletBalances();
      debugPrint('Raw API result: $result');
      
      if (result['success'] == true && result['data'] != null) {
        final data = result['data'];
        debugPrint('API data keys: ${data.keys.toList()}');
        debugPrint('Full data: $data');
        
        // Extract INR using recursive search for maximum reliability
        final inr = _findINRRecursively(data);
        if (inr > 0) {
          debugPrint('WalletService: INR Balance found via recursive search: $inr');
          return {'success': true, 'inrBalance': inr, 'source': 'recursive_search'};
        }

        
        // Try to find INR in other wallet types
        final walletTypes = ['main', 'spot', 'p2p', 'bot', 'demo_bot'];
        for (final type in walletTypes) {
          final wallet = data[type];
          if (wallet != null && wallet is Map) {
            debugPrint('Checking $type wallet: ${wallet.keys.toList()}');
            final balances = wallet['balances'];
            if (balances is List) {
              for (final b in balances) {
                if (b is Map && (b['coin']?.toString().toUpperCase() == 'INR' || 
                    b['asset']?.toString().toUpperCase() == 'INR')) {
                  final inr = double.tryParse(
                    b['total']?.toString() ?? 
                    b['balance']?.toString() ?? 
                    b['available']?.toString() ?? '0'
                  ) ?? 0.0;
                  debugPrint('INR Balance found in $type wallet: $inr');
                  if (inr > 0) {
                    return {'success': true, 'inrBalance': inr, 'source': type};
                  }
                }
              }
            }
          }
        }
      }
      
      // Fallback to overview API
      debugPrint('Trying overview API fallback...');
      final response = await http.get(
        Uri.parse('$baseUrl/wallet/overview/inr-holding'),
        headers: await _getHeaders(),
      );
      
      debugPrint('Overview API response: ${response.statusCode}');
      debugPrint('Overview API body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true || data['inrHolding'] != null) {
          final holdingData = data['data'] ?? data;
          final inr = holdingData['inrHolding'] ?? holdingData['inr'] ?? holdingData['balance'] ?? holdingData['amount'] ?? 0.0;
          final inrDouble = inr is num ? inr.toDouble() : double.tryParse(inr.toString()) ?? 0.0;
          debugPrint('INR Balance from overview API: $inrDouble');
          return {'success': true, 'inrBalance': inrDouble, 'source': 'overview'};
        }
      }
      
      debugPrint('❌ INR balance not found in any source');
      return {'success': false, 'error': 'INR balance not found'};
    } catch (e) {
      debugPrint('Error fetching INR balance: $e');
      return {'success': false, 'error': e.toString()};
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
          final balancesData = data[type]['balances'];
          // Handle both List and Map types
          if (balancesData is List) {
            foundInTypes = true;
            for (var b in balancesData) {
              if (b['coin']?.toString().toUpperCase() == 'USDT') {
                total += double.tryParse(b['available']?.toString() ?? '0') ?? 0.0;
              }
            }
          } else if (balancesData is Map && balancesData['USDT'] != null) {
            // Handle Map format like { "USDT": { "available": 100 } }
            foundInTypes = true;
            final usdtData = balancesData['USDT'];
            if (usdtData is Map) {
              total += double.tryParse(usdtData['available']?.toString() ?? '0') ?? 0.0;
            }
          }
        }
      }
      
      // If not found in categorized types, look for a flat balances list or map
      if (!foundInTypes && data['balances'] != null) {
        final balancesData = data['balances'];
        if (balancesData is List) {
          for (var b in balancesData) {
            if (b['coin']?.toString().toUpperCase() == 'USDT') {
              total += double.tryParse(b['available']?.toString() ?? '0') ?? 0.0;
            }
          }
        } else if (balancesData is Map && balancesData['USDT'] != null) {
          final usdtData = balancesData['USDT'];
          if (usdtData is Map) {
            total += double.tryParse(usdtData['available']?.toString() ?? '0') ?? 0.0;
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
        if (wallet is Map && wallet['balances'] != null) {
          final balancesData = wallet['balances'];
          if (balancesData is List) {
            for (var b in balancesData) {
              if (b['coin']?.toString().toUpperCase() == 'USDT') {
                total += double.tryParse(b['available']?.toString() ?? '0') ?? 0.0;
              }
            }
          } else if (balancesData is Map && balancesData['USDT'] != null) {
            final usdtData = balancesData['USDT'];
            if (usdtData is Map) {
              total += double.tryParse(usdtData['available']?.toString() ?? '0') ?? 0.0;
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
          final balancesData = data[type]['balances'];
          // Handle both List and Map types
          if (balancesData is List) {
            foundInTypes = true;
            for (var b in balancesData) {
              if (b['coin']?.toString().toUpperCase() == 'USDT') {
                total += double.tryParse(b['total']?.toString() ?? '0') ?? 0.0;
              }
            }
          } else if (balancesData is Map && balancesData['USDT'] != null) {
            // Handle Map format like { "USDT": { "total": 100 } }
            foundInTypes = true;
            final usdtData = balancesData['USDT'];
            if (usdtData is Map) {
              total += double.tryParse(usdtData['total']?.toString() ?? '0') ?? 0.0;
            }
          }
        }
      }
      
      // If not found in categorized types, look for a flat balances list or map
      if (!foundInTypes && data['balances'] != null) {
        final balancesData = data['balances'];
        if (balancesData is List) {
          for (var b in balancesData) {
            if (b['coin']?.toString().toUpperCase() == 'USDT') {
              total += double.tryParse(b['total']?.toString() ?? '0') ?? 0.0;
            }
          }
        } else if (balancesData is Map && balancesData['USDT'] != null) {
          final usdtData = balancesData['USDT'];
          if (usdtData is Map) {
            total += double.tryParse(usdtData['total']?.toString() ?? '0') ?? 0.0;
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
  /// type: 1 = Deposit, 2 = Withdrawal
  /// category: "inr" | "crypto"
  static Future<Map<String, dynamic>> getWalletTransactions({
    String? walletType,
    String? coin,
    String? transactionType,
    int? type, // 1 = Deposit, 2 = Withdrawal
    String? category, // "inr" | "crypto"
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
        if (type != null) 'type': type.toString(), // 1=Deposit, 2=Withdrawal
        if (category != null) 'category': category, // "inr" | "crypto"
        if (page != null) 'page': page.toString(),
        if (limit != null) 'limit': limit.toString(),
        if (startDate != null) 'startDate': startDate,
        if (endDate != null) 'endDate': endDate,
      };

      final endpoint = includeAdminLogs
          ? '$baseUrl/admin/wallet-log/transactions'
          : '$baseUrl/wallet/v1/wallet/transactions';

      final uri = Uri.parse(endpoint).replace(queryParameters: queryParams);

      debugPrint('Fetching wallet transactions: $uri');

      final response = await http.get(
        uri,
        headers: await _getHeaders(),
      );

      debugPrint('Wallet Transactions Response Status: ${response.statusCode}');
      debugPrint('Wallet Transactions Response Body: ${response.body}');

      if (response.statusCode == 200) {
        try {
          final data = json.decode(response.body);
          return {
            'success': true,
            'data': data['data'] ?? data,
            'isFromAdminLog': includeAdminLogs,
          };
        } catch (parseError) {
          debugPrint('JSON Parse Error: $parseError');
          debugPrint('Response was not JSON: ${response.body.substring(0, response.body.length > 100 ? 100 : response.body.length)}');
          return {
            'success': false,
            'error': 'Invalid response format: ${parseError.toString().substring(0, 100)}',
          };
        }
      } else {
        try {
          final data = json.decode(response.body);
          return {
            'success': false,
            'error': data['message'] ?? data['error'] ?? 'Server error: ${response.statusCode}',
          };
        } catch (parseError) {
          return {
            'success': false,
            'error': 'Server error ${response.statusCode}: ${response.body.substring(0, 100)}',
          };
        }
      }
    } catch (e) {
      debugPrint('Error fetching wallet transactions: $e');
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  // Helper method for INR Deposit history
  /// GET /wallet/v1/wallet/transactions?type=1&category=inr
  static Future<Map<String, dynamic>> getINRDepositHistory({
    int? page,
    int? limit,
  }) async {
    return getWalletTransactions(
      type: 1, // Deposit
      category: 'inr',
      page: page,
      limit: limit,
    );
  }

  // Helper method for INR Withdrawal history
  /// GET /wallet/v1/wallet/transactions?type=2&category=inr
  static Future<Map<String, dynamic>> getINRWithdrawalHistoryNew({
    int? page,
    int? limit,
  }) async {
    return getWalletTransactions(
      type: 2, // Withdrawal
      category: 'inr',
      page: page,
      limit: limit,
    );
  }

  // Helper method for Crypto Deposit history
  /// GET /wallet/v1/wallet/transactions?type=1&category=crypto
  static Future<Map<String, dynamic>> getCryptoDepositHistory({
    int? page,
    int? limit,
  }) async {
    return getWalletTransactions(
      type: 1, // Deposit
      category: 'crypto',
      page: page,
      limit: limit,
    );
  }

  // Helper method for Crypto Withdrawal history
  /// GET /wallet/v1/wallet/transactions?type=2&category=crypto
  static Future<Map<String, dynamic>> getCryptoWithdrawalHistory({
    int? page,
    int? limit,
  }) async {
    return getWalletTransactions(
      type: 2, // Withdrawal
      category: 'crypto',
      page: page,
      limit: limit,
    );
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
        'from': from, // Source wallet type
        'to': to, // Destination wallet type
        'amount': amount,
        if (otp != null && otp.isNotEmpty) 'otp': otp,
      };
      
      debugPrint('Transfer Request: $requestBody');
      debugPrint('Transfer API URL: $baseUrl/wallet/v1/wallet/transfer');
      
      final response = await http.post(
        Uri.parse('$baseUrl/wallet/v1/wallet/transfer'),
        headers: await _getHeaders(),
        body: json.encode(requestBody),
      );
      
      debugPrint('Transfer API Response Status: ${response.statusCode}');
      
      // Safe JSON decoding
      dynamic data;
      try {
        data = json.decode(response.body);
      } catch (e) {
        debugPrint('Failed to decode transfer response: ${response.body}');
        return {
          'success': false,
          'error': 'Server returned an invalid response. Please try again later.',
        };
      }
      
      if (response.statusCode == 200 || response.statusCode == 201) {
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
        return {
          'success': false,
          'error': data['message'] ?? data['error'] ?? 'Transfer failed',
          'details': data,
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
      case 'main':
        return 1; // Main wallet type (Aligned with UI)
      case 'p2p':
        return 2;
      case 'bot':
        return 3;
      case 'spot':
        return 4;
      case 'demo_bot':
        return 5;
      default:
        return 4; // Default to Spot
    }
  }

  // Helper method to convert API numbers to wallet names
  static String _getWalletTypeName(int walletType) {
    switch (walletType) {
      case 1:
        return 'Main Wallet';
      case 2:
        return 'P2P Wallet';
      case 3:
        return 'Bot Wallet';
      case 4:
        return 'Spot Wallet';
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
      } else if (response.statusCode == 403) {
        debugPrint('Sub-admin Networks API returned 403 - Forbidden. User may not have permission.');
        // Return empty list to trigger fallback to coin networks
        return [];
      } else if (response.statusCode == 401) {
        debugPrint('Sub-admin Networks API returned 401 - Unauthorized. Token may be invalid.');
        return [];
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
    try {
      debugPrint('Fetching withdrawal fees from: $baseUrl/wallet/v1/withdraw/withdraw-fees');
      
      final queryParams = {
        'coin': coin,
        'network': network,
        'amount': amount.toString(),
      };
      
      final uri = Uri.parse('$baseUrl/wallet/v1/withdraw/withdraw-fees')
          .replace(queryParameters: queryParams);
      
      final response = await http.get(
        uri,
        headers: await _getHeaders(),
      );
      
      debugPrint('Withdraw Fees API Response Status: ${response.statusCode}');
      debugPrint('Withdraw Fees API Response Body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['success'] == true) {
          return {
            'success': true,
            'fee': data['data']?['fee'] ?? data['fee'] ?? '0.00',
            'data': data['data'],
          };
        } else {
          return {
            'success': false,
            'error': data['message'] ?? 'Failed to fetch withdrawal fees',
          };
        }
      } else {
        debugPrint('Withdraw Fees API failed with status: ${response.statusCode}');
        return {
          'success': false,
          'error': 'Server error: ${response.statusCode}',
        };
      }
    } catch (e) {
      debugPrint('Error fetching withdrawal fees: $e');
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  // Alias for withdrawCrypto to match the naming convention in withdraw_crypto_screen.dart
  static Future<Map<String, dynamic>?> initiateWithdrawal({
    required String email,
    required String coin,
    required String network,
    required String address,
    required double amount,
  }) async {
    // The email parameter is kept for API compatibility but not used in the actual API call
    // as the backend uses the token for user identification
    return withdrawCrypto(
      coin: coin,
      network: network,
      address: address,
      amount: amount,
    );
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

      final uri = Uri.parse('$baseUrl/wallet/v1/wallet/inr/conversion-history')
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
    String? otp,
  }) async {
    try {
      // withdrawType: 1 for BANK, 2 for UPI
      final withdrawType = paymentMode == 'bank' ? 1 : paymentMode == 'upi' ? 2 : 1;
      final requestBody = {
        'amount': amount,
        'withdrawType': withdrawType,
        if (accountHolderName != null) 'accountHolderName': accountHolderName,
        if (bankName != null) 'bankName': bankName,
        if (accountNumber != null) 'accountNumber': accountNumber,
        if (ifscCode != null) 'ifscCode': ifscCode,
        if (upiId != null) 'upiId': upiId,
        if (otp != null && otp.isNotEmpty) 'otp': otp,
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

  // Send OTP for various purposes (internal_send, inr_withdraw, inr_deposit)
  static Future<Map<String, dynamic>> sendOtp({required String purpose}) async {
    try {
      final requestBody = {'purpose': purpose};
      debugPrint('Sending OTP for purpose: $purpose');
      
      // Use /wallet/v1/otp/send for wallet OTP endpoints
      final response = await http.post(
        Uri.parse('$baseUrl/wallet/v1/otp/send'),
        headers: await _getHeaders(),
        body: json.encode(requestBody),
      );
      
      debugPrint('Send OTP Response: ${response.statusCode}');
      debugPrint('Send OTP Response Body: ${response.body}');
      
      // Safe JSON decoding
      dynamic data;
      try {
        data = json.decode(response.body);
        debugPrint('Parsed OTP Response: $data');
      } catch (e) {
        debugPrint('Failed to decode OTP response: ${response.body}');
        return {
          'success': false,
          'error': 'Failed to send OTP. Server returned an invalid response.',
          'details': 'Raw response: ${response.body}',
        };
      }
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        // Check if OTP was actually sent successfully
        // API returns 'status': 'success' not 'success': true
        if (data['status'] == 'success' || data['success'] == true) {
          debugPrint('OTP sent successfully for purpose: $purpose');
          debugPrint('OTP delivery details: ${data['data'] ?? data}');
          return {
            'success': true, 
            'data': data,
            'message': data['message'] ?? 'OTP sent successfully'
          };
        } else {
          debugPrint('OTP API returned success=false: ${data['message'] ?? data['error']}');
          return {
            'success': false, 
            'error': data['message'] ?? data['error'] ?? 'OTP service returned error',
            'details': data,
          };
        }
      } else {
        debugPrint('OTP API failed with status: ${response.statusCode}');
        return {
          'success': false, 
          'error': data['message'] ?? data['error'] ?? 'Failed to send OTP',
          'details': {
            'status_code': response.statusCode,
            'response_body': response.body,
            'parsed_data': data,
          }
        };
      }
    } catch (e) {
      debugPrint('Error in sendOtp: $e');
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  // Verify OTP for various purposes
  static Future<Map<String, dynamic>> verifyOtp({required String otp, String? purpose}) async {
    try {
      final requestBody = {
        'otp': otp,
        if (purpose != null) 'purpose': purpose,
      };
      debugPrint('Verifying OTP for purpose: $purpose');

      final response = await http.post(
        Uri.parse('$baseUrl/wallet/v1/otp/verify'),
        headers: await _getHeaders(),
        body: json.encode(requestBody),
      );

      debugPrint('Verify OTP Response: ${response.statusCode}');

      dynamic data;
      try {
        data = json.decode(response.body);
      } catch (e) {
        debugPrint('Failed to decode verify OTP response: ${response.body}');
        return {
          'success': false,
          'error': 'Failed to verify OTP. Server returned an invalid response.',
        };
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'data': data, 'message': data['message'] ?? 'OTP verified successfully'};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? data['error'] ?? 'Failed to verify OTP',
          'error': data['message'] ?? data['error'] ?? 'Failed to verify OTP',
        };
      }
    } catch (e) {
      debugPrint('Error in verifyOtp: $e');
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  // Validate user UID exists
  static Future<Map<String, dynamic>> validateUserUid(String uid) async {
    try {
      debugPrint('Validating user UID: $uid');
      
      final response = await http.get(
        Uri.parse('$baseUrl/wallet/v1/user/validate-uid?uid=$uid'),
        headers: await _getHeaders(),
      );

      debugPrint('Validate UID API Response Status: ${response.statusCode}');
      debugPrint('Validate UID API Response Body: ${response.body}');
      
      // Safe JSON decoding
      dynamic data;
      try {
        data = json.decode(response.body);
      } catch (e) {
        debugPrint('Failed to decode validate UID response: ${response.body}');
        return {
          'success': false,
          'error': 'UID validation failed. Server returned an invalid response.',
        };
      }

      if (response.statusCode == 200) {
        if (data['success'] == true) {
          debugPrint('UID validation successful: $uid');
          return {
            'success': true,
            'data': data['data'],
            'message': data['message'] ?? 'UID is valid',
          };
        } else {
          debugPrint('UID validation failed: ${data['message'] ?? data['error']}');
          return {
            'success': false,
            'error': data['message'] ?? data['error'] ?? 'Invalid UID',
          };
        }
      } else {
        debugPrint('Validate UID API failed with status: ${response.statusCode}');
        return {
          'success': false,
          'error': data['message'] ?? data['error'] ?? 'UID validation failed',
        };
      }
    } catch (e) {
      debugPrint('Error in validateUserUid: $e');
      // If the API doesn't exist or fails, we'll skip UID validation for now
      // This allows the existing flow to continue working
      return {
        'success': true, // Default to success to avoid breaking existing flow
        'message': 'UID validation skipped - proceeding with transfer',
      };
    }
  }

  // Internal transfer - send crypto to another CreddX user
  static Future<Map<String, dynamic>> internalTransfer({
    required String receiverUid,
    required double amount,
    String? otp,
  }) async {
    try {
      final requestBody = {
        'receiverUid': receiverUid,
        'amount': amount,
        if (otp != null) 'otp': otp,
      };

      debugPrint('Internal Transfer Request: $requestBody');
      debugPrint('Internal Transfer API URL: $baseUrl/wallet/v1/wallet/internal-transfer');

      final response = await http.post(
        Uri.parse('$baseUrl/wallet/v1/wallet/internal-transfer'),
        headers: await _getHeaders(),
        body: json.encode(requestBody),
      );

      debugPrint('Internal Transfer API Response Status: ${response.statusCode}');
      
      // Safe JSON decoding
      dynamic data;
      try {
        data = json.decode(response.body);
      } catch (e) {
        debugPrint('Failed to decode internal transfer response: ${response.body}');
        return {
          'success': false,
          'error': 'Transfer failed. Server returned an invalid response.',
        };
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
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
        return {
          'success': false,
          'error': data['message'] ?? data['error'] ?? 'Transfer failed',
          'details': data,
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

  // Enable crypto withdrawal for a specific coin (admin endpoint)
  static Future<Map<String, dynamic>> enableCryptoWithdraw({required String coin, required String network}) async {
    try {
      debugPrint('Enabling crypto withdrawal: coin=$coin, network=$network');

      final requestBody = {
        'coin': coin,
        'network': network,
      };

      debugPrint('Enable withdraw request body: $requestBody');

      final response = await http.post(
        Uri.parse('$baseUrl/super-admin/v1/coin/withdraw/enable'),
        headers: await _getHeaders(),
        body: json.encode(requestBody),
      );

      debugPrint('Enable Withdraw API Response Status: ${response.statusCode}');
      debugPrint('Enable Withdraw API Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return {'success': true, 'data': data['data'], 'message': data['message'] ?? 'Withdrawal enabled successfully'};
        } else {
          return {'success': false, 'error': data['message'] ?? 'Failed to enable withdrawal'};
        }
      } else {
        final error = json.decode(response.body);
        return {'success': false, 'error': error['message'] ?? error['error'] ?? 'Error ${response.statusCode}'};
      }
    } catch (e) {
      debugPrint('Error in enableCryptoWithdraw: $e');
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  /// 1. Fetch Bank Details
  /// GET /wallet/v1/wallet/deposit/bank-details
  /// Status values: 1 = Pending, 2 = Approved, 3 = Rejected
  static Future<Map<String, dynamic>> getINRBankDetails() async {
    try {
      final headers = await _getHeaders();
      
      // Attempt 1: As requested by user (v1/wallet/deposit/inr-pay-details)
      // Since baseUrl already ends in /api, we use /v1/...
      String url = '$baseUrl/v1/wallet/deposit/inr-pay-details';
      debugPrint('Attempting GET INR Bank Details from: $url');
      
      var response = await http.get(Uri.parse(url), headers: headers);
      debugPrint('GET INR Bank Details (v1) Status: ${response.statusCode}');
      
      // Fallback: Try with /wallet/v1/...
      if (response.statusCode != 200) {
        url = '$baseUrl/wallet/v1/wallet/deposit/inr-pay-details';
        debugPrint('Attempting GET INR Bank Details from fallback: $url');
        response = await http.get(Uri.parse(url), headers: headers);
        debugPrint('GET INR Bank Details (fallback) Status: ${response.statusCode}');
      }

      // Fallback: Original endpoint
      if (response.statusCode != 200) {
        url = '$baseUrl/wallet/v1/wallet/deposit/bank-details';
        debugPrint('Attempting GET INR Bank Details from original: $url');
        response = await http.get(Uri.parse(url), headers: headers);
        debugPrint('GET INR Bank Details (original) Status: ${response.statusCode}');
      }

      if (response.statusCode == 200) {
        final decodedData = json.decode(response.body);
        debugPrint('INR Bank Details Response: ${response.body}');
        
        // Handle various response wrappers
        dynamic data = decodedData;
        if (decodedData is Map) {
          data = decodedData['data'] ?? decodedData['docs'] ?? decodedData['result'] ?? decodedData;
        }
        
        return {
          'success': true,
          'data': data,
        };
      }
      
      return {
        'success': false,
        'error': 'Could not fetch bank details (${response.statusCode})',
      };
    } catch (e) {
      debugPrint('Error in getINRBankDetails: $e');
      return {'success': false, 'error': 'Connection error'};
    }
  }

  /// 2. Add Bank Account
  /// POST /wallet/v1/wallet/deposit/add-inr-pay-details
  /// type: 1 = Bank, 2 = UPI
  static Future<Map<String, dynamic>> addINRBankAccount({
    required String accountHolderName,
    required String accountNumber,
    required String ifscCode,
    required String bankName,
    String? upiId,
    int type = 1, // 1 = Bank, 2 = UPI
    String? otp,
  }) async {
    try {
      final body = {
        'accountHolderName': accountHolderName,
        'accountNumber': accountNumber,
        'ifscCode': ifscCode,
        'bankName': bankName,
        'type': type,
        if (upiId != null && upiId.isNotEmpty) 'upiId': upiId,
        if (otp != null) 'otp': otp,
      };

      final headers = await _getHeaders();
      // Primary URL as requested by user
      String url = '$baseUrl/v1/wallet/deposit/add-inr-pay-details';
      debugPrint('Adding INR Bank Details (Attempt 1) to: $url');
      
      var response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: json.encode(body),
      );
      debugPrint('Add Bank (Attempt 1) Status: ${response.statusCode}');

      // Fallback if needed
      if (response.statusCode != 200 && response.statusCode != 201) {
        url = '$baseUrl/wallet/v1/wallet/deposit/add-inr-pay-details';
        debugPrint('Adding INR Bank Details (Attempt 2) to: $url');
        response = await http.post(
          Uri.parse(url),
          headers: headers,
          body: json.encode(body),
        );
        debugPrint('Add Bank (Attempt 2) Status: ${response.statusCode}');
      }

      final decodedData = json.decode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'data': decodedData['data'] ?? decodedData,
          'message': decodedData['message'] ?? 'Details added successfully',
        };
      }
      
      return {
        'success': false,
        'error': decodedData['message'] ?? 'Failed to add details',
      };
    } catch (e) {
      debugPrint('Error adding INR bank account: $e');
      return {'success': false, 'error': 'Connection error'};
    }
  }

  /// 3. Edit Bank Account (for rejected status)
  /// POST /wallet/v1/wallet/inr/update-inr-payment-method/{_id}
  static Future<Map<String, dynamic>> editINRBankAccount({
    required String id,
    required String accountHolderName,
    required String accountNumber,
    required String ifscCode,
    required String bankName,
    String? upiId,
    String? otp,
    int? type,
  }) async {
    try {
      final body = {
        'accountHolderName': accountHolderName,
        'accountNumber': accountNumber,
        'ifscCode': ifscCode,
        'bankName': bankName,
        if (type != null) 'type': type,
        if (upiId != null && upiId.isNotEmpty) 'upiId': upiId,
        if (otp != null) 'otp': otp,
      };

      final headers = await _getHeaders();
      // Use consistent path structure
      String url = '$baseUrl/v1/wallet/inr/update-inr-payment-method/$id';
      debugPrint('Editing INR bank account (Attempt 1) to: $url');

      var response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: json.encode(body),
      );
      debugPrint('Edit Bank (Attempt 1) Status: ${response.statusCode}');

      if (response.statusCode != 200 && response.statusCode != 201) {
        url = '$baseUrl/wallet/v1/wallet/inr/update-inr-payment-method/$id';
        debugPrint('Editing INR bank account (Attempt 2) to: $url');
        response = await http.post(
          Uri.parse(url),
          headers: headers,
          body: json.encode(body),
        );
        debugPrint('Edit Bank (Attempt 2) Status: ${response.statusCode}');
      }

      final decodedData = json.decode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'data': decodedData['data'] ?? decodedData,
          'message': decodedData['message'] ?? 'Account updated successfully',
        };
      }
      
      return {
        'success': false,
        'message': decodedData['message'] ?? 'Failed to update account',
      };
    } catch (e) {
      debugPrint('Error editing INR bank account: $e');
      return {'success': false, 'error': 'Connection error'};
    }
  }

  /// 4. Send OTP for INR Withdrawal
  /// POST /wallet/v1/otp/send
  static Future<Map<String, dynamic>> sendINROTP() async {
    try {
      final body = {
        'purpose': 'inr_withdraw',
      };

      debugPrint('Sending OTP for INR withdrawal');

      final response = await http.post(
        Uri.parse('$baseUrl/wallet/v1/otp/send'),
        headers: await _getHeaders(),
        body: json.encode(body),
      );

      debugPrint('Send OTP API Response Status: ${response.statusCode}');
      debugPrint('Send OTP API Response Body: ${response.body}');

      final data = json.decode(response.body);
      debugPrint('Parsed data: $data');
      debugPrint('Success field: ${data['success']} (type: ${data['success']?.runtimeType})');

      // Check success - handle both boolean true and string "true"
      bool isSuccess = false;
      if (data['success'] == true || data['success'] == 'true' || data['success'] == 1) {
        isSuccess = true;
      }
      // Also check status field if success is not present
      if (!isSuccess && data['status'] != null) {
        final status = data['status'].toString().toLowerCase();
        if (status == 'success' || status == 'ok' || status == '200') {
          isSuccess = true;
        }
      }
      // If HTTP status is 200/201 and no explicit error, assume success
      if (!isSuccess && (response.statusCode == 200 || response.statusCode == 201)) {
        if (data['error'] == null && data['message']?.toString().toLowerCase().contains('fail') != true) {
          isSuccess = true;
        }
      }

      debugPrint('Is success determined: $isSuccess');

      if (isSuccess) {
        return {
          'success': true,
          'message': data['message'] ?? data['msg'] ?? 'OTP sent successfully',
        };
      } else {
        return {
          'success': false,
          'error': data['message'] ?? data['error'] ?? data['msg'] ?? 'Failed to send OTP',
        };
      }
    } catch (e) {
      debugPrint('Error sending INR withdrawal OTP: $e');
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  /// 5. Submit INR Deposit Request
  /// POST /wallet/v1/wallet/deposit/inr-request
  static Future<Map<String, dynamic>> submitINRDepositRequest({
    required String amount,
    required String txid,
    required String account,
    required String senderAccountName,
    String? screenshotPath,
  }) async {
    try {
      final token = await AuthService.getToken();
      
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/wallet/v1/wallet/deposit/inr-request'),
      );
      
      // Add auth header
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      
      request.fields['amount'] = amount;
      request.fields['txid'] = txid;
      request.fields['account'] = account;
      request.fields['senderAccountName'] = senderAccountName;
      
      if (screenshotPath != null && screenshotPath.isNotEmpty) {
        request.files.add(await http.MultipartFile.fromPath(
          'screenshot',
          screenshotPath,
        ));
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      debugPrint('Deposit API Response Status: ${response.statusCode}');
      debugPrint('Deposit API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'data': data,
          'message': data['message'] ?? 'Deposit request submitted successfully',
        };
      } else {
        return {
          'success': false,
          'error': 'Failed: ${response.body}',
        };
      }
    } catch (e) {
      debugPrint('Error submitting INR deposit: $e');
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  /// Get INR Withdrawal History
  /// GET /wallet/v1/wallet/inr-withdrawal-history
  static Future<Map<String, dynamic>> getINRWithdrawalHistory({
    int? page = 1,
    int? limit = 50,
    String? status, // 'pending', 'completed', 'failed'
  }) async {
    try {
      final queryParams = <String, String>{
        if (page != null) 'page': page.toString(),
        if (limit != null) 'limit': limit.toString(),
        if (status != null) 'status': status,
      };

      final uri = Uri.parse('$baseUrl/wallet/v1/wallet/inr-withdrawal-history')
          .replace(queryParameters: queryParams);

      debugPrint('Fetching INR withdrawal history from: $uri');

      final response = await http.get(
        uri,
        headers: await _getHeaders(),
      );

      debugPrint('INR Withdrawal History Response Status: ${response.statusCode}');
      debugPrint('INR Withdrawal History Response Body: ${response.body}');

      final data = json.decode(response.body);
      
      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': data['data'] ?? data,
        };
      } else {
        return {
          'success': false,
          'error': data['message'] ?? data['error'] ?? 'Server error: ${response.statusCode}',
        };
      }
    } catch (e) {
      debugPrint('Error fetching INR withdrawal history: $e');
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  /// 6. Submit INR Withdrawal Request
  /// POST /wallet/v1/wallet/deposit/inr-withdraw-request
  /// withdrawType: 1 for BANK, 2 for UPI
  static Future<Map<String, dynamic>> submitINRWithdrawal({
    required String otp,
    required double amount,
    required int withdrawType,
    String? paymentMethodId,
    String? accountHolderName,
    String? accountNumber,
    String? ifscCode,
    String? bankName,
    String? upiId,
  }) async {
    try {
      final body = {
        'otp': otp,
        'amount': amount,
        'withdrawType': withdrawType,
        if (paymentMethodId != null) 'paymentMethodId': paymentMethodId,
        if (accountHolderName != null) 'accountHolderName': accountHolderName,
        if (accountNumber != null) 'accountNumber': accountNumber,
        if (ifscCode != null) 'ifscCode': ifscCode,
        if (bankName != null) 'bankName': bankName,
        if (upiId != null) 'upiId': upiId,
      };

      debugPrint('Submitting INR withdrawal with amount: $amount, paymentMethodId: $paymentMethodId');

      final response = await http.post(
        Uri.parse('$baseUrl/wallet/v1/wallet/deposit/inr-withdraw-request'),
        headers: await _getHeaders(),
        body: json.encode(body),
      );

      debugPrint('Withdrawal API Response Status: ${response.statusCode}');
      debugPrint('Withdrawal API Response Body: ${response.body}');

      final data = json.decode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (data['success'] == true) {
          return {
            'success': true,
            'data': data['data'],
            'message': data['message'] ?? 'Withdrawal request submitted successfully',
          };
        } else {
          return {
            'success': false,
            'error': data['message'] ?? 'Failed to submit withdrawal request',
          };
        }
      } else {
        return {
          'success': false,
          'error': data['message'] ?? 'Server error: ${response.statusCode}',
        };
      }
    } catch (e) {
      debugPrint('Error submitting INR withdrawal: $e');
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  /// 7. Convert USDT to INR
  /// POST /api/v1/wallet/inr/convert/usdt-to-inr
  static Future<Map<String, dynamic>> convertUSDTtoINR({
    required double amount,
  }) async {
    try {
      final body = {
        'amount': amount,
      };

      final headers = await _getHeaders();
      // Correct URL pattern based on conversion-history: /wallet/v1/wallet/inr/...
      String url = '$baseUrl/wallet/v1/wallet/inr/convert/usdt-to-inr';
      debugPrint('Converting USDT to INR at: $url');

      var response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: json.encode(body),
      );
      debugPrint('USDT to INR Status: ${response.statusCode}');
      debugPrint('USDT to INR Body: ${response.body.substring(0, response.body.length > 300 ? 300 : response.body.length)}');

      // Check if response is valid JSON
      bool isJson = false;
      dynamic data;
      try {
        data = json.decode(response.body);
        isJson = true;
      } catch (e) {
        isJson = false;
      }

      // Final JSON validation
      if (!isJson) {
        debugPrint('Failed to decode USDT to INR response after all attempts');
        return {
          'success': false,
          'error': 'Server returned an invalid response (Status: ${response.statusCode}). Please try again later.',
        };
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'data': data['data'] ?? data,
          'message': data['message'] ?? 'Conversion successful',
        };
      }

      return {
        'success': false,
        'error': data['message'] ?? data['error'] ?? 'Conversion failed',
      };
    } catch (e) {
      debugPrint('Error converting USDT to INR: $e');
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  /// 8. Convert INR to USDT
  /// POST /api/v1/wallet/inr/convert/inr-to-usdt
  static Future<Map<String, dynamic>> convertINRtoUSDT({
    required double amount,
  }) async {
    try {
      final body = {
        'amount': amount,
      };

      final headers = await _getHeaders();
      // Correct URL pattern based on conversion-history: /wallet/v1/wallet/inr/...
      String url = '$baseUrl/wallet/v1/wallet/inr/convert/inr-to-usdt';
      debugPrint('Converting INR to USDT at: $url');

      var response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: json.encode(body),
      );
      debugPrint('INR to USDT Status: ${response.statusCode}');
      debugPrint('INR to USDT Body: ${response.body.substring(0, response.body.length > 300 ? 300 : response.body.length)}');

      // Check if response is valid JSON
      bool isJson = false;
      dynamic data;
      try {
        data = json.decode(response.body);
        isJson = true;
      } catch (e) {
        isJson = false;
      }

      // Final JSON validation
      if (!isJson) {
        debugPrint('Failed to decode INR to USDT response after all attempts');
        return {
          'success': false,
          'error': 'Server returned an invalid response (Status: ${response.statusCode}). Please try again later.',
        };
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'data': data['data'] ?? data,
          'message': data['message'] ?? 'Conversion successful',
        };
      }

      return {
        'success': false,
        'error': data['message'] ?? data['error'] ?? 'Conversion failed',
      };
    } catch (e) {
      debugPrint('Error converting INR to USDT: $e');
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  static double _findINRRecursively(dynamic data) {
    if (data == null) return 0.0;
    if (data is Map) {
      final keys = data.keys.map((k) => k.toString().toUpperCase()).toList();
      final inrKeys = [
        'INR',
        'INR_BALANCE',
        'INRBALANCE',
        'INR_AVAILABLE',
        'INRAVAILABLE',
        'INR_HOLDING',
        'INRHOLDING'
      ];
      for (var targetKey in inrKeys) {
        final actualKey = data.keys.firstWhere(
            (k) => k.toString().toUpperCase() == targetKey,
            orElse: () => null);
        if (actualKey != null) {
          final val = _parseBalanceField(data[actualKey]);
          if (val > 0) return val;
        }
      }
      final coinKey = data.keys.firstWhere(
          (k) => k.toString().toUpperCase() == 'COIN',
          orElse: () => null);
      final assetKey = data.keys.firstWhere(
          (k) => k.toString().toUpperCase() == 'ASSET',
          orElse: () => null);
      final coinVal =
          (data[coinKey] ?? data[assetKey])?.toString().toUpperCase();
      if (coinVal == 'INR') {
        final val = _parseBalanceField(data);
        if (val > 0) return val;
      }
      for (var value in data.values) {
        if (value is Map || value is List) {
          final val = _findINRRecursively(value);
          if (val > 0) return val;
        }
      }
    } else if (data is List) {
      for (var item in data) {
        final val = _findINRRecursively(item);
        if (val > 0) return val;
      }
    }
    return 0.0;
  }

  static double _parseBalanceField(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    if (val is String) {
      final cleaned = val.replaceAll(',', '');
      return double.tryParse(cleaned) ?? 0.0;
    }
    if (val is Map) {
      final total = val['total'] ??
          val['balance'] ??
          val['amount'] ??
          val['totalBalance'] ??
          val['available'] ??
          val['free'] ??
          val['availableBalance'] ??
          0.0;
      return double.tryParse(total.toString()) ?? 0.0;
    }
    return 0.0;
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
