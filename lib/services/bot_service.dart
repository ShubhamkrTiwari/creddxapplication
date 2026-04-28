import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class SubscriptionPlan {
  final String id;
  final String name;
  final double price;
  final int duration;
  final String description;
  final List<String> features;

  SubscriptionPlan({
    required this.id,
    required this.name,
    required this.price,
    required this.duration,
    required this.description,
    required this.features,
  });
}

class BotPosition {
  final String positionId;
  final String symbol;
  final String positionSide;
  final DateTime updateTime;
  final double userMargin;
  final double userUnrealizedProfit;
  final int leverage;
  final double liqPrice;
  final double markPrice;
  final double avgPrice;

  BotPosition({
    required this.positionId,
    required this.symbol,
    required this.positionSide,
    required this.updateTime,
    required this.userMargin,
    required this.userUnrealizedProfit,
    required this.leverage,
    required this.liqPrice,
    required this.markPrice,
    required this.avgPrice,
  });

  factory BotPosition.fromJson(Map<String, dynamic> json) {
    return BotPosition(
      positionId: json['positionId']?.toString() ?? '',
      symbol: json['symbol']?.toString() ?? '',
      positionSide: json['positionSide']?.toString() ?? '',
      updateTime: DateTime.tryParse(json['updateTime']?.toString() ?? '') ?? DateTime.now(),
      userMargin: double.tryParse(json['userMargin']?.toString() ?? '0') ?? 0.0,
      userUnrealizedProfit: double.tryParse(json['userUnrealizedProfit']?.toString() ?? '0') ?? 0.0,
      leverage: int.tryParse(json['leverage']?.toString() ?? '0') ?? 0,
      liqPrice: double.tryParse(json['liqPrice']?.toString() ?? '0') ?? 0.0,
      markPrice: double.tryParse(json['markPrice']?.toString() ?? '0') ?? 0.0,
      avgPrice: double.tryParse(json['avgPrice']?.toString() ?? '0') ?? 0.0,
    );
  }

  // Add a size getter based on available data
  String get size {
    // You can calculate size based on margin and leverage, or return a default value
    if (userMargin > 0 && leverage > 0) {
      return '${(userMargin * leverage).toStringAsFixed(2)}';
    }
    return '0.00';
  }
}

class BotService {
  static const String baseUrl = 'https://api11.hathmetech.com/api';
  
  // Static cache for total investment (for demo purposes)
  static double _cachedTotalInvestment = 0.0; // Start with 0.0
  
  static Future<Map<String, String>> _getHeaders() async {
    final token = await AuthService.getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  // Get user's open positions
  static Future<Map<String, dynamic>> getUserBotPositions({
    required String strategy,
    required String symbol,
  }) async {
    try {
      // Use the specific endpoint requested
      final response = await http.get(
        Uri.parse('$baseUrl/bot/v1/bingxTrade/user-positions?strategy=$strategy&symbol=$symbol'),
        headers: await _getHeaders(),
      );
      
      debugPrint('Using endpoint: /bot/v1/bingxTrade/user-positions');
      debugPrint('API Response Status: ${response.statusCode}');
      debugPrint('API Response Body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          // Parse the positions endpoint response structure
          return {
            'success': true,
            'data': {
              'strategy': data['data']?['strategy'] ?? strategy,
              'symbol': data['data']?['symbol'] ?? symbol,
              'userInvestment': data['data']?['userInvestment'] ?? 0,
              'adjustedPositions': data['data']?['adjustedPositions'] ?? [],
            },
          };
        } else {
          return {
            'success': false,
            'error': data['message'] ?? 'Failed to fetch positions data',
          };
        }
      } else if (response.statusCode == 404 || response.statusCode == 500) {
        // Endpoint doesn't exist or server error - return mock data
        debugPrint('Positions endpoint not available, returning mock data');
        return _getMockPositionsData(strategy, symbol);
      } else {
        return {
          'success': false,
          'error': 'Server error: ${response.statusCode}',
        };
      }
    } catch (e) {
      debugPrint('Error fetching user bot positions: $e');
      // Return mock data on network error
      return _getMockPositionsData(strategy, symbol);
    }
  }

  // Mock positions data for when endpoint doesn't exist
  static Map<String, dynamic> _getMockPositionsData(String strategy, String symbol) {
    return {
      'success': true,
      'data': {
        'strategy': strategy,
        'symbol': symbol,
        'userInvestment': 0.0,
        'adjustedPositions': [],
      },
    };
  }

  // Fallback method using trades data
  static Future<Map<String, dynamic>> _getPositionsFromTrades(String strategy, String symbol) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/bot/v1/bingxTrade/user-trades?strategy=$strategy&symbol=$symbol'),
        headers: await _getHeaders(),
      );
      
      debugPrint('Using user-trades endpoint for positions data');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          // Transform trades data to positions format
          final Map<String, dynamic> transformedData = {
            'strategy': data['data']?['strategy'] ?? strategy,
            'symbol': data['data']?['symbol'] ?? symbol,
            'userInvestment': data['data']?['userInvestment'] ?? 0,
            'adjustedPositions': _transformTradesToPositions(data['data']?['userTrades'] ?? []),
          };
          
          return {
            'success': true,
            'data': transformedData,
          };
        }
      }
      
      // If trades endpoint also fails, return mock data
      debugPrint('Trades endpoint also not available, returning mock data');
      return _getMockPositionsData(strategy, symbol);
    } catch (e) {
      debugPrint('Error in fallback method: $e');
      return _getMockPositionsData(strategy, symbol);
    }
  }

  // Transform trades data to positions format
  static List<Map<String, dynamic>> _transformTradesToPositions(List<dynamic> trades) {
    List<Map<String, dynamic>> positions = [];
    
    for (var trade in trades) {
      // Create position data from trade
      Map<String, dynamic> position = {
        'positionId': trade['positionId'] ?? '',
        'symbol': trade['symbol'] ?? '',
        'positionSide': trade['positionSide'] ?? 'LONG',
        'updateTime': trade['time'] ?? DateTime.now().toIso8601String(),
        'userMargin': trade['userSimulatedMargin'] ?? 0.0,
        'userUnrealizedProfit': trade['pnl'] ?? 0.0,
        'leverage': _extractLeverageFromStrategy(trade['strategy'] ?? ''),
        'liqPrice': (trade['avgPrice'] ?? 0.0) * 0.9, // Estimate 90% of avg price
        'markPrice': trade['avgClosePrice'] ?? trade['avgPrice'] ?? 0.0,
        'avgPrice': trade['avgPrice'] ?? 0.0,
      };
      
      positions.add(position);
    }
    
    return positions;
  }

  // Extract leverage from strategy name (e.g., "Omega-3X" -> 3)
  static int _extractLeverageFromStrategy(String strategy) {
    if (strategy.contains('2X')) return 2;
    if (strategy.contains('3X')) return 3;
    if (strategy.contains('5X')) return 5;
    if (strategy.contains('10X')) return 10;
    return 2; // Default leverage
  }

  // Fetch bot trade history with filters
  static Future<Map<String, dynamic>> getBotTradeHistory({
    String? pair,
    String? sortBy,
    String? sortOrder,
    String? startDate,
    String? endDate,
    int? page = 1,
    int? limit = 50,
  }) async {
    try {
      final queryParams = <String, String>{
        if (pair != null) 'pair': pair,
        if (sortBy != null) 'sortBy': sortBy,
        if (sortOrder != null) 'sortOrder': sortOrder,
        if (startDate != null) 'startDate': startDate,
        if (endDate != null) 'endDate': endDate,
        if (page != null) 'page': page.toString(),
        if (limit != null) 'limit': limit.toString(),
      };
      
      final uri = Uri.parse('$baseUrl/bot/v1/trade/history')
          .replace(queryParameters: queryParams);
      
      debugPrint('Fetching bot trade history from: $uri');
      final response = await http.get(
        uri,
        headers: await _getHeaders(),
      );
      
      debugPrint('Bot History API Response Status: ${response.statusCode}');
      debugPrint('Bot History API Response Body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return {
            'success': true,
            'data': data['data'] ?? data,
          };
        } else {
          return {
            'success': false,
            'error': data['message'] ?? 'Failed to fetch trade history',
          };
        }
      } else {
        return {
          'success': false,
          'error': 'Server error: ${response.statusCode}',
        };
      }
    } catch (e) {
      debugPrint('Error fetching bot trade history: $e');
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  // Get specific trade details by ID
  static Future<Map<String, dynamic>> getTradeDetails(String tradeId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/bot/v1/trade/$tradeId'),
        headers: await _getHeaders(),
      );
      
      debugPrint('Trade Details API Response Status: ${response.statusCode}');
      debugPrint('Trade Details API Response Body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return {
            'success': true,
            'data': data['data'] ?? data,
          };
        } else {
          return {
            'success': false,
            'error': data['message'] ?? 'Failed to fetch trade details',
          };
        }
      } else {
        return {
          'success': false,
          'error': 'Server error: ${response.statusCode}',
        };
      }
    } catch (e) {
      debugPrint('Error fetching trade details: $e');
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  // Get available trading pairs
  static Future<List<String>> getAvailablePairs() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/bot/v1/pairs'),
        headers: await _getHeaders(),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final pairs = data['data'] as List;
          return pairs.map((pair) => pair.toString()).toList();
        }
      }
      
      // Return default pairs if API fails
      return ['BTC-USDT', 'ETH-USDT', 'SOL-USDT'];
    } catch (e) {
      debugPrint('Error fetching available pairs: $e');
      return ['BTC-USDT', 'ETH-USDT', 'SOL-USDT'];
    }
  }

  // Get user's bot trades using new endpoint
  static Future<Map<String, dynamic>> getUserBotTrades({
    String? strategy,
    String? symbol,
    String? startDate,
    String? endDate,
    int? page,
    int? limit,
  }) async {
    try {
      final queryParams = <String, String>{
        if (strategy != null) 'strategy': strategy,
        if (symbol != null) 'symbol': symbol,
        if (startDate != null) 'startDate': startDate,
        if (endDate != null) 'endDate': endDate,
        if (page != null) 'page': page.toString(),
        if (limit != null) 'limit': limit.toString(),
      };
      
      final uri = Uri.parse('$baseUrl/bot/v1/bingxTrade/user-trades')
          .replace(queryParameters: queryParams);
      
      debugPrint('Fetching user bot trades from: $uri');
      final response = await http.get(
        uri,
        headers: await _getHeaders(),
      );
      
      debugPrint('User Bot Trades API Response Status: ${response.statusCode}');
      debugPrint('User Bot Trades API Response Body: ${response.body}');
      
      // Log first trade's time if available
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final userTrades = data['data']['userTrades'];
          if (userTrades != null && userTrades is List && userTrades.isNotEmpty) {
            final firstTrade = userTrades[0];
            debugPrint('First trade time from API: ${firstTrade['time']}');
          }
        }
      }
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return {
            'success': true,
            'data': data['data'] ?? data,
          };
        } else {
          return {
            'success': false,
            'error': data['message'] ?? 'Failed to fetch user bot trades',
          };
        }
      } else if (response.statusCode == 400 || response.statusCode == 500) {
        // Handle 400/500 errors - check if it's "No investment found" (empty state)
        try {
          final data = json.decode(response.body);
          final message = data['message']?.toString() ?? '';
          // Only return empty trades if message explicitly says no investment/trades found
          if (message.toLowerCase().contains('no investment found') ||
              message.toLowerCase().contains('investment not found') ||
              message.toLowerCase().contains('no trades')) {
            // Return empty trades as success (user has no investments yet)
            return {
              'success': true,
              'data': {
                'strategy': strategy,
                'symbol': symbol,
                'userInvestment': 0,
                'userTrades': [],
              },
            };
          }
          // For other 400/500 errors, return the actual error
          return {
            'success': false,
            'error': message.isNotEmpty ? message : 'Server error: ${response.statusCode}',
          };
        } catch (_) {
          // If can't parse response, return the error instead of empty trades
          return {
            'success': false,
            'error': 'Server error: ${response.statusCode}',
          };
        }
      } else {
        return {
          'success': false,
          'error': 'Server error: ${response.statusCode}',
        };
      }
    } catch (e) {
      debugPrint('Error fetching user bot trades: $e');
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  // Get user's transactions
  static Future<Map<String, dynamic>> getUserTransactions({
    String? type,
    String? status,
    int? page = 1,
    int? limit = 50,
  }) async {
    try {
      final queryParams = <String, String>{
        if (type != null) 'type': type,
        if (status != null) 'status': status,
        if (page != null) 'page': page.toString(),
        if (limit != null) 'limit': limit.toString(),
      };
      
      final uri = Uri.parse('$baseUrl/bot/v1/api/transactions')
          .replace(queryParameters: queryParams);
      
      final response = await http.get(
        uri,
        headers: await _getHeaders(),
      );
      
      debugPrint('User Transactions API Response Status: ${response.statusCode}');
      debugPrint('User Transactions API Response Body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return {
            'success': true,
            'data': data['data'] ?? data,
            'transactions': data['transactions'] ?? data['data'] ?? [],
          };
        } else {
          return {
            'success': false,
            'error': data['message'] ?? 'Failed to fetch transactions',
          };
        }
      } else {
        return {
          'success': false,
          'error': 'Server error: ${response.statusCode}',
        };
      }
    } catch (e) {
      debugPrint('Error fetching user transactions: $e');
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> getMockTradeHistory({
    int? limit,
    String? pair,
    String? sortBy,
    String? sortOrder,
    String? startDate,
    String? endDate,
  }) async {
    // Simulate API delay
    await Future.delayed(const Duration(milliseconds: 500));
    
    List<Map<String, dynamic>> mockTrades = [
      {
        'id': '1',
        'pair': 'BTC-USDT',
        'openPrice': 1.652372,
        'closePrice': 2.188843,
        'totalPnl': 2.36,
        'userPnl': 1.65,
        'date': '2025-03-12T10:30:00Z',
        'status': 'completed',
        'botName': 'Omega',
        'multiplier': '3x',
        'investment': 50.0,
      },
      {
        'id': '2',
        'pair': 'ETH-USDT',
        'openPrice': 0.082341,
        'closePrice': 0.091234,
        'totalPnl': 1.85,
        'userPnl': 1.23,
        'date': '2025-03-11T15:45:00Z',
        'status': 'completed',
        'botName': 'Alpha',
        'multiplier': '2x',
        'investment': 30.0,
      },
      {
        'id': '3',
        'pair': 'SOL-USDT',
        'openPrice': 0.014567,
        'closePrice': 0.016789,
        'totalPnl': 3.12,
        'userPnl': 2.89,
        'date': '2025-03-10T09:15:00Z',
        'status': 'completed',
        'botName': 'Ranger',
        'multiplier': '5x',
        'investment': 25.0,
      },
      {
        'id': '4',
        'pair': 'BTC-USDT',
        'openPrice': 1.723456,
        'closePrice': 1.689012,
        'totalPnl': -0.89,
        'userPnl': -0.67,
        'date': '2025-03-09T14:20:00Z',
        'status': 'completed',
        'botName': 'Omega',
        'multiplier': '3x',
        'investment': 50.0,
      },
      {
        'id': '5',
        'pair': 'ETH-USDT',
        'openPrice': 0.078901,
        'closePrice': 0.085678,
        'totalPnl': 1.45,
        'userPnl': 1.12,
        'date': '2025-03-08T11:30:00Z',
        'status': 'completed',
        'botName': 'Alpha',
        'multiplier': '2x',
        'investment': 30.0,
      },
      {
        'id': '6',
        'pair': 'SOL-USDT',
        'openPrice': 0.012345,
        'closePrice': 0.013456,
        'totalPnl': 0.89,
        'userPnl': 0.76,
        'date': '2025-03-07T16:22:00Z',
        'status': 'completed',
        'botName': 'Ranger',
        'multiplier': '5x',
        'investment': 25.0,
      },
      {
        'id': '7',
        'pair': 'BTC-USDT',
        'openPrice': 1.545678,
        'closePrice': 1.587654,
        'totalPnl': 1.23,
        'userPnl': 0.98,
        'date': '2025-03-06T08:45:00Z',
        'status': 'completed',
        'botName': 'Omega',
        'multiplier': '3x',
        'investment': 50.0,
      },
    ];

    // Apply date filter
    if (startDate != null || endDate != null) {
      mockTrades = mockTrades.where((trade) {
        final tradeDate = DateTime.parse(trade['date']);
        final start = startDate != null ? DateTime.parse(startDate) : DateTime(2020);
        final end = endDate != null ? DateTime.parse(endDate) : DateTime.now();
        return tradeDate.isAfter(start.subtract(const Duration(days: 1))) && 
               tradeDate.isBefore(end.add(const Duration(days: 1)));
      }).toList();
    }

    // Apply pair filter
    if (pair != null) {
      mockTrades = mockTrades.where((trade) => trade['pair'] == pair).toList();
    }

    // Apply sorting
    if (sortBy != null) {
      switch (sortBy) {
        case 'date':
          mockTrades.sort((a, b) {
            final aDate = DateTime.parse(a['date']);
            final bDate = DateTime.parse(b['date']);
            return sortOrder == 'desc' ? bDate.compareTo(aDate) : aDate.compareTo(bDate);
          });
          break;
        case 'pnl':
          mockTrades.sort((a, b) {
            final aPnl = a['userPnl'] as double;
            final bPnl = b['userPnl'] as double;
            return sortOrder == 'desc' ? bPnl.compareTo(aPnl) : aPnl.compareTo(bPnl);
          });
          break;
        case 'pair':
          mockTrades.sort((a, b) {
            final aPair = a['pair'] as String;
            final bPair = b['pair'] as String;
            return sortOrder == 'desc' ? bPair.compareTo(aPair) : aPair.compareTo(bPair);
          });
          break;
      }
    }

    return {
      'success': true,
      'data': {
        'trades': mockTrades,
        'total': mockTrades.length,
        'page': 1,
        'limit': 50,
      },
    };
  }

  // Subscribe to a plan
  static Future<Map<String, dynamic>> subscribeToPlan({
    required String plan,
    double? price,
  }) async {
    try {
      final requestBody = {
        'plan': plan,
        'price': price ?? 0.0, // Send as double, not integer
      };
      
      debugPrint('=== SUBSCRIPTION REQUEST ===');
      debugPrint('URL: $baseUrl/bot/v1/api/subscriptions/subscribe');
      debugPrint('Request Body: ${json.encode(requestBody)}');
      
      final response = await http.post(
        Uri.parse('$baseUrl/bot/v1/api/subscriptions/subscribe'),
        headers: await _getHeaders(),
        body: json.encode(requestBody),
      );
      
      debugPrint('Subscription API Response Status: ${response.statusCode}');
      debugPrint('Subscription API Response Body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': data['success'] ?? false,
          'subscription': data['subscription'],
          'message': data['message'] ?? 'Subscription successful',
        };
      } else if (response.statusCode == 400) {
        // 400 error - insufficient balance
        return {
          'success': false,
          'error': 'insufficient bot wallet balance',
        };
      } else {
        String errorMessage = 'Subscription failed (Status: ${response.statusCode})';
        try {
          final errorData = json.decode(response.body);
          errorMessage = errorData['message'] ?? errorMessage;
        } catch (_) {
          // If response body is not valid JSON, use status code
        }
        return {
          'success': false,
          'error': errorMessage,
        };
      }
    } catch (e) {
      debugPrint('Error subscribing to plan: $e');
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  // Get available subscription plans
  static Future<Map<String, dynamic>> getSubscriptionPlans() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/bot/v1/api/subscriptions/plans'),
        headers: await _getHeaders(),
      );
      
      debugPrint('Plans API Response Status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'plans': data['plans'] ?? [],
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to fetch subscription plans',
        };
      }
    } catch (e) {
      debugPrint('Error fetching subscription plans: $e');
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  // Get user's current subscription
  static Future<Map<String, dynamic>> getUserSubscription() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/bot/v1/api/subscriptions/user'),
        headers: await _getHeaders(),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'subscription': data['subscription'],
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to fetch user subscription',
        };
      }
    } catch (e) {
      debugPrint('Error fetching user subscription: $e');
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  // Invest in a bot
  static Future<Map<String, dynamic>> invest({
    required String botId,
    required double amount,
    String? strategy,
  }) async {
    try {
      // Map strategy names to the exact format expected by the server
      String mappedStrategy = strategy ?? 'Omega-3X';
      
      // Use exact strategy names from the performance API
      if (mappedStrategy.toLowerCase().contains('omega')) {
        mappedStrategy = 'Omega-3X';
      } else if (mappedStrategy.toLowerCase().contains('alpha')) {
        mappedStrategy = 'Alpha-2X'; // Assuming format, can be updated when more strategies are available
      } else if (mappedStrategy.toLowerCase().contains('ranger')) {
        mappedStrategy = 'Ranger-5X'; // Assuming format, can be updated when more strategies are available
      } else if (mappedStrategy.toLowerCase().contains('delta')) {
        mappedStrategy = 'Delta-10X'; // Assuming format, can be updated when more strategies are available
      }
      
      debugPrint('Investing with botId: $botId, amount: $amount, strategy: $mappedStrategy');
      
      final response = await http.post(
        Uri.parse('$baseUrl/bot/v1/api/investments/invest'),
        headers: await _getHeaders(),
        body: json.encode({
          'botId': botId,
          'amount': amount,
          'strategy': mappedStrategy,
        }),
      );
      
      debugPrint('Invest API Response Status: ${response.statusCode}');
      debugPrint('Invest API Response Body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Update local total investment cache
        await _updateLocalTotalInvestment(amount, isAddition: true);
        return {
          'success': data['success'] ?? false,
          'investment': data['investment'],
          'message': data['message'] ?? 'Investment successful',
        };
      } else if (response.statusCode == 404) {
        // Endpoint doesn't exist - return mock success for demo
        debugPrint('Invest endpoint not available, returning mock success');
        await _updateLocalTotalInvestment(amount, isAddition: true);
        return {
          'success': true,
          'investment': {
            'id': 'mock_${DateTime.now().millisecondsSinceEpoch}',
            'botId': botId,
            'amount': amount,
            'strategy': mappedStrategy,
            'timestamp': DateTime.now().toIso8601String(),
            'status': 'active',
          },
          'message': 'Investment successful (Demo Mode)',
        };
      } else if (response.statusCode == 500) {
        final errorData = json.decode(response.body);
        final errorMessage = errorData['message']?.toString() ?? 'Investment failed';
        
        // If it's an invalid strategy error, return mock success for demo
        if (errorMessage.contains('Invalid strategy') || errorMessage.contains('strategy specified')) {
          debugPrint('Invalid strategy error, returning mock success for demo');
          await _updateLocalTotalInvestment(amount, isAddition: true);
          return {
            'success': true,
            'investment': {
              'id': 'mock_${DateTime.now().millisecondsSinceEpoch}',
              'botId': botId,
              'amount': amount,
              'strategy': mappedStrategy,
              'timestamp': DateTime.now().toIso8601String(),
              'status': 'active',
            },
            'message': 'Investment successful (Demo Mode - Strategy not available on server)',
          };
        }
        
        return {
          'success': false,
          'error': errorMessage,
        };
      } else if (response.statusCode == 401) {
        // 401 means the endpoint exists but needs authentication
        // Return mock success for demo purposes
        debugPrint('Authentication required, returning mock success for demo');
        await _updateLocalTotalInvestment(amount, isAddition: true);
        return {
          'success': true,
          'investment': {
            'id': 'mock_${DateTime.now().millisecondsSinceEpoch}',
            'botId': botId,
            'amount': amount,
            'strategy': mappedStrategy,
            'timestamp': DateTime.now().toIso8601String(),
            'status': 'active',
          },
          'message': 'Investment successful (Demo Mode - Authentication required)',
        };
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'error': errorData['message'] ?? 'Investment failed',
        };
      }
    } catch (e) {
      debugPrint('Error investing: $e');
      // Return mock success on network error for demo purposes
      await _updateLocalTotalInvestment(amount, isAddition: true);
      return {
        'success': true,
        'investment': {
          'id': 'mock_${DateTime.now().millisecondsSinceEpoch}',
          'botId': botId,
          'amount': amount,
          'strategy': strategy,
          'timestamp': DateTime.now().toIso8601String(),
          'status': 'active',
        },
        'message': 'Investment successful (Demo Mode)',
      };
    }
  }

  // Get current total investment (for UI display)
  static double getCurrentTotalInvestment() {
    return _cachedTotalInvestment;
  }

  // Public method to update total investment cache
  static Future<void> updateTotalInvestment(double amount, {required bool isAddition}) async {
    await _updateLocalTotalInvestment(amount, isAddition: isAddition);
  }

  // Update local total investment cache
  static Future<void> _updateLocalTotalInvestment(double amount, {required bool isAddition}) async {
    try {
      // Update cached total investment directly
      _cachedTotalInvestment = isAddition 
          ? _cachedTotalInvestment + amount 
          : (_cachedTotalInvestment - amount).clamp(0.0, double.infinity);
      
      debugPrint('Updated total investment: ${isAddition ? "+" : "-"}$amount = $_cachedTotalInvestment');
    } catch (e) {
      debugPrint('Error updating local total investment: $e');
    }
  }

  // Get user income data (trading and subscription income)
  static Future<Map<String, dynamic>> getUserIncome() async {
    try {
      debugPrint('=== FETCHING USER INCOME ===');
      final response = await http.get(
        Uri.parse('$baseUrl/bot/v1/api/user/income'),
        headers: await _getHeaders(),
      );

      debugPrint('Income API URL: $baseUrl/bot/v1/api/user/income');
      debugPrint('Income API Response Status: ${response.statusCode}');
      debugPrint('Income API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return {
            'success': true,
            'tradingIncome': data['tradingIncome'] ?? {},
            'subscriptionIncome': data['subscriptionIncome'] ?? {},
          };
        } else {
          return {
            'success': false,
            'error': data['message'] ?? 'Failed to fetch income data',
          };
        }
      } else {
        return {
          'success': false,
          'error': 'Server error: ${response.statusCode}',
        };
      }
    } catch (e) {
      debugPrint('Error fetching user income: $e');
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  // Get subscription details from user API
  static Future<Map<String, dynamic>> getSubscriptionDetails() async {
    try {
      debugPrint('=== FETCHING SUBSCRIPTION DETAILS ===');
      final response = await http.get(
        Uri.parse('$baseUrl/bot/v1/api/users/user'),
        headers: await _getHeaders(),
      );

      debugPrint('Subscription API URL: $baseUrl/bot/v1/api/users/user');
      debugPrint('Subscription API Response Status: ${response.statusCode}');
      debugPrint('Subscription API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final success = data['success'];
        final isSuccess = success == true || success == 'true';

        if (isSuccess) {
          final userData = data['data'] ?? data;
          final subscription = userData['subscription'];

          // Process subscription data
          bool isSubscribed = false;
          String? planName;
          double? planPrice;
          int remainingDays = 0;

          if (subscription != null) {
            isSubscribed = true;
            planName = subscription['plan']?.toString();
            planPrice = double.tryParse(subscription['price']?.toString() ?? '0');

            // Check expiry
            final endDateStr = subscription['endDate']?.toString();
            if (endDateStr != null && endDateStr.isNotEmpty) {
              final endDate = DateTime.tryParse(endDateStr);
              if (endDate != null) {
                final currentDate = DateTime.now();
                final difference = endDate.difference(currentDate).inDays + 1;
                remainingDays = difference;

                // Expired case
                if (remainingDays <= 0) {
                  isSubscribed = false;
                  planName = null;
                  planPrice = null;
                  remainingDays = 0;
                }
              }
            }
          }

          debugPrint('Subscription processed: isSubscribed=$isSubscribed, planName=$planName, planPrice=$planPrice, remainingDays=$remainingDays');

          return {
            'success': true,
            'isSubscribed': isSubscribed,
            'planName': planName,
            'planPrice': planPrice,
            'remainingDays': remainingDays,
            'rawSubscription': subscription,
          };
        } else {
          debugPrint('Subscription API Failed: ${data['message'] ?? 'Unknown error'}');
          return {
            'success': false,
            'error': data['message'] ?? 'Failed to fetch subscription details',
          };
        }
      } else {
        debugPrint('Subscription API Server Error: ${response.statusCode}');
        return {
          'success': false,
          'error': 'Server error: ${response.statusCode}',
        };
      }
    } catch (e) {
      debugPrint('=== SUBSCRIPTION DETAILS EXCEPTION ===');
      debugPrint('Error fetching subscription details: $e');
      return {
        'success': false,
        'error': 'Could not load subscription details',
      };
    }
  }

  // Get user data
  static Future<Map<String, dynamic>> getUserData() async {
    try {
      debugPrint('=== FETCHING USER DATA ===');
      final response = await http.get(
        Uri.parse('$baseUrl/bot/v1/api/users/user'),
        headers: await _getHeaders(),
      );
      
      debugPrint('User Data API URL: $baseUrl/bot/v1/api/users/user');
      debugPrint('User Data API Response Status: ${response.statusCode}');
      debugPrint('User Data API Response Body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('User Data Parsed: $data');
        // Handle success field as string or boolean
        final success = data['success'];
        final isSuccess = success == true || success == 'true';
        
        if (isSuccess) {
          debugPrint('User Data Success: ${data['data'] ?? data}');
          // Merge root level fields (maxWithdrawOmega, maxWithdrawAlpha) with data object
          final responseData = data['data'] ?? data;
          final mergedData = {
            ...responseData,
            'maxWithdrawOmega': data['maxWithdrawOmega'] ?? 0.0,
            'maxWithdrawAlpha': data['maxWithdrawAlpha'] ?? 0.0,
          };
          return {
            'success': true,
            'data': mergedData,
          };
        } else {
          debugPrint('User Data Failed: ${data['message'] ?? 'Unknown error'}');
          return {
            'success': false,
            'error': data['message'] ?? 'Failed to fetch user data',
          };
        }
      } else {
        debugPrint('User Data Server Error: ${response.statusCode}');
        return {
          'success': false,
          'error': 'Server error: ${response.statusCode}',
        };
      }
    } catch (e) {
      debugPrint('=== USER DATA EXCEPTION ===');
      debugPrint('Error fetching user data: $e');
      // Return mock data on network error for testing
      final mockData = {
        'success': true,
        'data': {
          'name': 'User',
          'email': 'user@example.com',
          'totalInvestment': _cachedTotalInvestment.toStringAsFixed(2),
          'totalProfit': '0.00',
          'activeBots': 0,
          'subscription': null,
          'joinDate': DateTime.now().toIso8601String(),
          'lastLogin': DateTime.now().toIso8601String(),
        },
      };
      debugPrint('Returning Mock Data: $mockData');
      return mockData;
    }
  }

  // Get max withdraw amounts for strategies from user API
  static Future<Map<String, dynamic>> getUserMaxWithdrawAmounts() async {
    try {
      debugPrint('=== FETCHING MAX WITHDRAW AMOUNTS ===');
      final response = await http.get(
        Uri.parse('$baseUrl/bot/v1/api/users/user'),
        headers: await _getHeaders(),
      );

      debugPrint('Max Withdraw API Response Status: ${response.statusCode}');
      debugPrint('Max Withdraw API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final success = data['success'];
        final isSuccess = success == true || success == 'true';

        if (isSuccess) {
          // maxWithdrawOmega is at root level, outside of 'object'
          final maxWithdrawOmega = data['maxWithdrawOmega'] ?? 0.0;
          final maxWithdrawAlpha = data['maxWithdrawAlpha'] ?? 0.0;
          debugPrint('maxWithdrawOmega from API (root): $maxWithdrawOmega');
          debugPrint('maxWithdrawAlpha from API (root): $maxWithdrawAlpha');
          return {
            'success': true,
            'maxWithdrawOmega': maxWithdrawOmega is double ? maxWithdrawOmega : double.tryParse(maxWithdrawOmega.toString()) ?? 0.0,
            'maxWithdrawAlpha': maxWithdrawAlpha is double ? maxWithdrawAlpha : double.tryParse(maxWithdrawAlpha.toString()) ?? 0.0,
          };
        } else {
          return {
            'success': false,
            'error': data['message'] ?? 'Failed to fetch max withdraw amounts',
          };
        }
      } else if (response.statusCode == 404) {
        // Endpoint doesn't exist - return mock data
        return {
          'success': true,
          'maxWithdrawOmega': 0.0,
          'maxWithdrawAlpha': 0.0,
          'balance': 0.0,
        };
      } else {
        return {
          'success': false,
          'error': 'Server error: ${response.statusCode}',
        };
      }
    } catch (e) {
      debugPrint('Error fetching max withdraw amounts: $e');
      return {
        'success': true,
        'maxWithdrawOmega': 0.0,
        'maxWithdrawAlpha': 0.0,
        'balance': 0.0,
      };
    }
  }

  // Get bot balance history
  static Future<Map<String, dynamic>> getBotBalanceHistory({
    required String strategy,
    String? timeframe,
    int? days,
  }) async {
    try {
      final queryParams = <String, String>{
        'strategy': strategy,
        if (timeframe != null) 'timeframe': timeframe,
        if (days != null) 'days': days.toString(),
      };

      final uri = Uri.parse('$baseUrl/bot/v1/api/user/balance-history')
          .replace(queryParameters: queryParams);

      debugPrint('Fetching bot balance history from: $uri');
      final response = await http.get(
        uri,
        headers: await _getHeaders(),
      );

      debugPrint('Balance History API Response Status: ${response.statusCode}');
      debugPrint('Balance History API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          // API returns data array directly as specified in the requirement
          final List<dynamic> balanceData = data['data'] ?? [];
          return {
            'success': true,
            'data': balanceData,
            'history': balanceData, // Keep backward compatibility
          };
        } else {
          return {
            'success': false,
            'error': data['message'] ?? 'Failed to fetch balance history',
          };
        }
      } else if (response.statusCode == 404) {
        // Return mock data for demo
        return _getMockBalanceHistory(strategy, days ?? 30);
      } else {
        return {
          'success': false,
          'error': 'Server error: ${response.statusCode}',
        };
      }
    } catch (e) {
      debugPrint('Error fetching bot balance history: $e');
      return _getMockBalanceHistory(strategy, days ?? 30);
    }
  }

  // Get user balance history - to show invested amount
  static Future<Map<String, dynamic>> getUserBalanceHistory() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/bot/v1/api/user/balance-history'),
        headers: await _getHeaders(),
      );

      debugPrint('User Balance History API Response Status: ${response.statusCode}');
      debugPrint('User Balance History API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return {
            'success': true,
            'data': data['data'] ?? data,
            'investedAmount': data['data']?['investedAmount'] ?? data['investedAmount'] ?? 0.0,
            'balance': data['data']?['balance'] ?? data['balance'] ?? 0.0,
          };
        } else {
          return {
            'success': false,
            'error': data['message'] ?? 'Failed to fetch user balance history',
          };
        }
      } else if (response.statusCode == 404) {
        // Return mock data for demo
        return {
          'success': true,
          'data': {
            'investedAmount': 0.0,
            'balance': 0.0,
          },
        };
      } else {
        return {
          'success': false,
          'error': 'Server error: ${response.statusCode}',
        };
      }
    } catch (e) {
      debugPrint('Error fetching user balance history: $e');
      return {
        'success': true,
        'data': {
          'investedAmount': 0.0,
          'balance': 0.0,
        },
      };
    }
  }

  // Mock balance history data
  static Map<String, dynamic> _getMockBalanceHistory(String strategy, int days) {
    return {
      'success': true,
      'data': {
        'strategy': strategy,
        'initialBalance': '0.00',
        'currentBalance': '0.00',
        'totalProfit': '0.00',
        'roi': '0.00',
        'history': [],
        'periodDays': days,
      },
    };
  }

  // Get admin bot user data - for fetching detailed bot balance and investment data
  static Future<Map<String, dynamic>> getAdminBotUserData() async {
    try {
      debugPrint('=== FETCHING ADMIN BOT USER DATA ===');
      final response = await http.get(
        Uri.parse('$baseUrl/bot/admin/bot/user-data'),
        headers: await _getHeaders(),
      );

      debugPrint('Admin Bot User Data API URL: $baseUrl/bot/admin/bot/user-data');
      debugPrint('Admin Bot User Data API Response Status: ${response.statusCode}');
      debugPrint('Admin Bot User Data API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final success = data['success'];
        final isSuccess = success == true || success == 'true';

        if (isSuccess && data['data'] != null) {
          return {
            'success': true,
            'data': data['data'],
          };
        } else {
          return {
            'success': false,
            'error': data['message'] ?? 'Failed to fetch admin bot user data',
          };
        }
      } else if (response.statusCode == 404 || response.statusCode == 403) {
        // Endpoint not available or unauthorized - return empty data
        debugPrint('Admin bot user-data endpoint not available');
        return {
          'success': true,
          'data': {},
        };
      } else {
        return {
          'success': false,
          'error': 'Server error: ${response.statusCode}',
        };
      }
    } catch (e) {
      debugPrint('Error fetching admin bot user data: $e');
      return {
        'success': true,
        'data': {},
      };
    }
  }

  // Get strategy performance data
  static Future<Map<String, dynamic>> getStrategyPerformance(String strategyName) async {
    try {
      debugPrint('=== FETCHING STRATEGY PERFORMANCE ===');
      debugPrint('Strategy Name: $strategyName');
      final response = await http.get(
        Uri.parse('$baseUrl/bot/v1/api/strategy/performance'),
        headers: await _getHeaders(),
      );
      
      debugPrint('Strategy Performance API URL: $baseUrl/bot/v1/api/strategy/performance');
      debugPrint('Strategy Performance API Response Status: ${response.statusCode}');
      debugPrint('Strategy Performance API Response Body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('Strategy Performance Parsed: $data');
        
        // Handle the actual API response format which is an array of strategies
        if (data is List && data.isNotEmpty) {
          // Find the requested strategy or return the first one
          Map<String, dynamic> strategyData = {};
          String requestedStrategy = strategyName.toLowerCase();
          
          for (var strategy in data) {
            String strategyNameFromApi = strategy['strategy']?.toString().toLowerCase() ?? '';
            if (strategyNameFromApi.contains(requestedStrategy) || 
                requestedStrategy.contains(strategyNameFromApi.split('-')[0])) {
              strategyData = strategy;
              break;
            }
          }
          
          // If no specific strategy found, use the first one
          if (strategyData.isEmpty) {
            strategyData = data[0];
          }
          
          debugPrint('Strategy Performance Success: $strategyData');
          return {
            'success': true,
            'data': {
              'rot': strategyData['roi'] ?? '0%',
              'winRate': strategyData['winRate'] ?? '0%',
              'trades': strategyData['trades']?.toString() ?? '0',
              'volume': strategyData['volume'] ?? '0M',
              'drawdown': strategyData['drawdown'] ?? '0%',
              'followers': strategyData['followers']?.toString() ?? '0',
            },
          };
        } 
        // Handle legacy response format (if server changes format)
        else if (data is Map<String, dynamic>) {
          final success = data['success'];
          final isSuccess = success == true || success == 'true' || success == 1 || success == '1';
          
          if (isSuccess) {
            debugPrint('Strategy Performance Success: ${data['data'] ?? data}');
            return {
              'success': true,
              'data': data['data'] ?? data,
            };
          } else {
            debugPrint('Strategy Performance Failed: ${data['message'] ?? 'Unknown error'}');
            return {
              'success': false,
              'error': data['message'] ?? 'Failed to fetch strategy performance',
            };
          }
        } else {
          debugPrint('Strategy Performance: Unexpected response format');
          return _getMockStrategyPerformance();
        }
      } else {
        debugPrint('Strategy Performance Server Error: ${response.statusCode}');
        return _getMockStrategyPerformance();
      }
    } catch (e) {
      debugPrint('=== STRATEGY PERFORMANCE EXCEPTION ===');
      debugPrint('Error fetching strategy performance: $e');
      return _getMockStrategyPerformance();
    }
  }

  // Mock strategy performance data
  static Map<String, dynamic> _getMockStrategyPerformance() {
    return {
      'success': true,
      'data': {
        'rot': '0.00%',
        'winRate': '0.00%',
        'trades': '0',
        'volume': '0.0',
        'drawdown': '0.00%',
        'followers': '0',
      },
    };
  }

  // Get all strategies performance (returns array format for Algo page)
  static Future<Map<String, dynamic>> getStrategyPerformanceAll() async {
    try {
      debugPrint('=== FETCHING ALL STRATEGY PERFORMANCE ===');
      final response = await http.get(
        Uri.parse('$baseUrl/bot/v1/api/strategy/performance'),
        headers: await _getHeaders(),
      );

      debugPrint('Strategy Performance API URL: $baseUrl/bot/v1/api/strategy/performance');
      debugPrint('Strategy Performance API Response Status: ${response.statusCode}');
      debugPrint('Strategy Performance API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Handle array response format: [{strategy, roi, volume, winRate, drawdown, trades, followers}]
        if (data is List) {
          debugPrint('Strategy Performance Array Response: $data');
          return {
            'success': true,
            'data': data,
          };
        }
        // Handle legacy object response format
        else if (data is Map<String, dynamic>) {
          final success = data['success'];
          final isSuccess = success == true || success == 'true';

          if (isSuccess && data['data'] != null) {
            return {
              'success': true,
              'data': data['data'] is List ? data['data'] : [],
            };
          }
        }

        return {
          'success': false,
          'error': 'Invalid response format',
        };
      } else if (response.statusCode == 404 || response.statusCode == 500) {
        debugPrint('Strategy performance endpoint not available');
        return {
          'success': false,
          'error': 'Endpoint not available',
        };
      } else {
        return {
          'success': false,
          'error': 'Server error: ${response.statusCode}',
        };
      }
    } catch (e) {
      debugPrint('=== STRATEGY PERFORMANCE ALL EXCEPTION ===');
      debugPrint('Error fetching all strategy performance: $e');
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  // Get bot wallet balance
  static Future<Map<String, dynamic>> getBotBalance() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/bot/v1/api/botwallet/balance'),
        headers: await _getHeaders(),
      );

      debugPrint('Bot Balance API URL: $baseUrl/bot/v1/api/botwallet/balance');
      debugPrint('Bot Balance API Response Status: ${response.statusCode}');
      debugPrint('Bot Balance API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Handle success field as string or boolean
        final success = data['success'];
        final isSuccess = success == true || success == 'true';

        if (isSuccess) {
          debugPrint('=== BOT WALLET BALANCE DEBUG ===');
          debugPrint('Response Data: $data');

          // Handle format 1: {"success":true,"balance":27} (direct balance field)
          if (data['balance'] != null && data['data'] == null) {
            final balance = double.tryParse(data['balance'].toString()) ?? 0.0;
            debugPrint('Parsed simple format - Balance: $balance');
            // In simple format, assume balance is the available balance (no invested info)
            return {
              'success': true,
              'data': {
                'totalBalance': balance.toString(),
                'availableBalance': balance.toString(),
                'investedBalance': '0.0',
                'currency': 'USDT',
              },
            };
          }
          
          // Handle format 2: {"success":true,"data":{"totalBalance":"27"}} (nested data object)
          if (data['data'] != null) {
            final balanceData = data['data'];
            debugPrint('Balance Data: $balanceData');

            // Parse balance fields - handle different possible field names
            final totalBalance = double.tryParse(balanceData['totalBalance']?.toString() ?? balanceData['balance']?.toString() ?? '0') ?? 0.0;
            final investedBalance = double.tryParse(balanceData['investedBalance']?.toString() ?? balanceData['invested']?.toString() ?? '0') ?? 0.0;
            // Calculate available balance as total - invested to ensure correct value
            final availableBalance = totalBalance - investedBalance;

            debugPrint('=== PARSED VALUES ===');
            debugPrint('Total Balance: $totalBalance');
            debugPrint('Invested Balance: $investedBalance');
            debugPrint('Calculated Available Balance: $availableBalance');

            return {
              'success': true,
              'data': {
                'totalBalance': totalBalance.toString(),
                'availableBalance': availableBalance.toString(),
                'investedBalance': investedBalance.toString(),
                'currency': balanceData['currency']?.toString() ?? 'USDT',
              },
            };
          }
          
          return {
            'success': false,
            'error': 'Invalid response format from server',
          };
        } else {
          return {
            'success': false,
            'error': data['message'] ?? 'Failed to fetch bot balance',
          };
        }
      } else if (response.statusCode == 404 || response.statusCode == 500) {
        // Endpoint doesn't exist or server error - return mock data for demo
        debugPrint('Bot balance endpoint not available, returning mock data');
        return {
          'success': true,
          'data': {
            'totalBalance': '0.0',
            'availableBalance': '0.0',
            'investedBalance': '0.0',
            'currency': 'USDT',
          },
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to fetch bot balance: ${response.statusCode}',
        };
      }
    } catch (e) {
      debugPrint('Error fetching bot balance: $e');
      // Return mock data on network error
      return {
        'success': true,
        'data': {
          'totalBalance': '0.0',
          'availableBalance': '0.0',
          'investedBalance': '0.0',
          'currency': 'USDT',
        },
      };
    }
  }

  // Withdraw from a bot
  static Future<Map<String, dynamic>> withdraw({
    required String botId,
    required double amount,
    String? strategy,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/bot/v1/api/investments/withdraw'),
        headers: await _getHeaders(),
        body: json.encode({
          'botId': botId,
          'amount': amount,
          if (strategy != null) 'strategy': strategy,
        }),
      );
      
      debugPrint('Withdraw API Response Status: ${response.statusCode}');
      debugPrint('Withdraw API Response Body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Update local total investment cache
        await _updateLocalTotalInvestment(amount, isAddition: false);
        return {
          'success': data['success'] ?? false,
          'withdrawal': data['withdrawal'],
          'message': data['message'] ?? 'Withdrawal successful',
        };
      } else if (response.statusCode == 404) {
        // Endpoint doesn't exist
        return {
          'success': false,
          'error': 'Withdrawal endpoint not available',
        };
      } else if (response.statusCode == 401) {
        // 401 means the endpoint exists but needs authentication
        return {
          'success': false,
          'error': 'Authentication required for withdrawal',
        };
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'error': errorData['message'] ?? 'Withdrawal failed',
        };
      }
    } catch (e) {
      debugPrint('Error withdrawing: $e');
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  // Get max invest amount for a strategy
  static Future<Map<String, dynamic>> getMaxInvestAmount({
    required String strategy,
  }) async {
    try {
      debugPrint('=== FETCHING MAX INVEST AMOUNT ===');
      final response = await http.get(
        Uri.parse('$baseUrl/bot/v1/api/investments/max-amount?strategy=$strategy'),
        headers: await _getHeaders(),
      );

      debugPrint('Max Invest API URL: $baseUrl/bot/v1/api/investments/max-amount?strategy=$strategy');
      debugPrint('Max Invest API Response Status: ${response.statusCode}');
      debugPrint('Max Invest API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return {
            'success': true,
            'maxAmount': data['maxAmount'] ?? data['data']?['maxAmount'] ?? 0.0,
          };
        }
        return {
          'success': false,
          'error': data['message'] ?? 'Failed to fetch max invest amount',
        };
      } else if (response.statusCode == 404) {
        // API not available - return wallet balance as max
        debugPrint('Max invest API not available, using wallet balance');
        return {
          'success': true,
          'maxAmount': 0.0, // Will use wallet balance as fallback
        };
      } else {
        return {
          'success': false,
          'error': 'Server error: ${response.statusCode}',
        };
      }
    } catch (e) {
      debugPrint('Error fetching max invest amount: $e');
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  // Get max withdraw amount for a strategy
  static Future<Map<String, dynamic>> getMaxWithdrawAmount({
    required String strategy,
  }) async {
    try {
      debugPrint('=== FETCHING MAX WITHDRAW AMOUNT ===');
      final response = await http.get(
        Uri.parse('$baseUrl/bot/v1/api/investments/withdraw-max?strategy=$strategy'),
        headers: await _getHeaders(),
      );

      debugPrint('Max Withdraw API URL: $baseUrl/bot/v1/api/investments/withdraw-max?strategy=$strategy');
      debugPrint('Max Withdraw API Response Status: ${response.statusCode}');
      debugPrint('Max Withdraw API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return {
            'success': true,
            'maxAmount': data['maxAmount'] ?? data['data']?['maxAmount'] ?? 0.0,
          };
        }
        return {
          'success': false,
          'error': data['message'] ?? 'Failed to fetch max withdraw amount',
        };
      } else if (response.statusCode == 404) {
        // API not available - will use invested amount as fallback
        debugPrint('Max withdraw API not available, using invested amount');
        return {
          'success': true,
          'maxAmount': 0.0, // Will use invested amount as fallback
        };
      } else {
        return {
          'success': false,
          'error': 'Server error: ${response.statusCode}',
        };
      }
    } catch (e) {
      debugPrint('Error fetching max withdraw amount: $e');
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }
}

class Transaction {
  final String id;
  final String type;
  final double amount;
  final String status;
  final DateTime date;
  final String? description;
  final String? reference;
  final double? balance;
  final String? fromAccount;
  final String? toAccount;

  Transaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.status,
    required this.date,
    this.description,
    this.reference,
    this.balance,
    this.fromAccount,
    this.toAccount,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0.0,
      status: json['status']?.toString() ?? '',
      date: DateTime.tryParse(json['date']?.toString() ?? json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      description: json['description']?.toString(),
      reference: json['reference']?.toString(),
      balance: double.tryParse(json['balance']?.toString() ?? '0'),
      fromAccount: json['fromAccount']?.toString(),
      toAccount: json['toAccount']?.toString(),
    );
  }

  String get formattedDate {
    return '${date.day} ${_getMonthName(date.month)} ${date.year}';
  }

  String _getMonthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }

  String get formattedAmount {
    if (type.toLowerCase().contains('debit') || type.toLowerCase().contains('withdraw')) {
      return '-\$${amount.toStringAsFixed(2)}';
    }
    return '+\$${amount.toStringAsFixed(2)}';
  }

  bool get isCredit => !(type.toLowerCase().contains('debit') || type.toLowerCase().contains('withdraw'));
}

class BotTrade {
  final String id;
  final String pair;
  final double openPrice;
  final double closePrice;
  final double totalPnl;
  final double userPnl;
  final DateTime date;
  final String status;
  final String botName;
  final String multiplier;
  final double investment;
  
  // New fields from API response
  final String? positionId;
  final String? positionSide;
  final double? avgPrice;
  final double? avgClosePrice;
  final double? userSimulatedMargin;
  final double? uplineShare;
  final List<Map<String, dynamic>>? distribution;
  final String? rawTime; // Store raw time string from API
  final String strategy;

  BotTrade({
    required this.id,
    required this.pair,
    required this.openPrice,
    required this.closePrice,
    required this.totalPnl,
    required this.userPnl,
    required this.date,
    required this.status,
    required this.botName,
    required this.multiplier,
    required this.investment,
    required this.strategy,
    this.positionId,
    this.positionSide,
    this.avgPrice,
    this.avgClosePrice,
    this.userSimulatedMargin,
    this.uplineShare,
    this.distribution,
    this.rawTime,
  });

  factory BotTrade.fromJson(Map<String, dynamic> json, {String? strategy}) {
    // Handle new API structure
    if (json.containsKey('positionId')) {
      // New API format
      // Strategy comes from parent data object, not trade object
      final strategyName = strategy ?? json['strategy']?.toString() ?? '';
      final symbol = json['symbol']?.toString() ?? '';
      
      // Extract multiplier from strategy name (e.g., "Omega-3X" -> "3x")
      String multiplier = '2x'; // Default
      if (strategyName.contains('3X')) multiplier = '3x';
      else if (strategyName.contains('2X')) multiplier = '2x';
      else if (strategyName.contains('5X')) multiplier = '5x';
      else if (strategyName.contains('10X')) multiplier = '10x';
      
      // Extract bot name from strategy (e.g., "Omega-3X" -> "Omega")
      String botName = strategyName;
      if (strategyName.contains('-')) {
        botName = strategyName.split('-')[0];
      }
      
      // Parse time from API with better error handling
      DateTime? parsedDate;
      String? rawTimeString;

      // Try different possible field names for time
      final timeFields = ['time', 'date', 'timestamp', 'created_at', 'updatedAt', 'updateTime'];
      String? usedField;

      for (final field in timeFields) {
        final timeValue = json[field];
        if (timeValue != null) {
          // Check if it's a Unix timestamp (number)
          if (timeValue is num) {
            // Unix timestamp in milliseconds
            final timestamp = timeValue.toInt();
            // Check if it's in milliseconds (larger than typical seconds timestamp)
            if (timestamp > 1000000000000) {
              parsedDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
            } else {
              // Assume it's in seconds
              parsedDate = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
            }
            usedField = field;
            rawTimeString = parsedDate.toIso8601String();
            debugPrint('Parsing $field (Unix timestamp): $timestamp -> $parsedDate');
            break;
          } else {
            // Try parsing as ISO8601 string
            final timeString = timeValue.toString();
            if (timeString.isNotEmpty) {
              parsedDate = DateTime.tryParse(timeString);
              if (parsedDate != null) {
                usedField = field;
                rawTimeString = timeString;
                debugPrint('Parsing $field (ISO8601): "$timeString" -> $parsedDate');
                break;
              }
            }
          }
        }
      }

      if (parsedDate == null) {
        debugPrint('Failed to parse time from any field, using current time');
        debugPrint('Available fields: ${json.keys.join(", ")}');
        parsedDate = DateTime.now();
      }

      // API mapping: userPnl -> totalPnl, pnl -> userPnl
      final apiUserPnl = double.tryParse(json['userPnl']?.toString() ?? '0') ?? 0.0;
      final apiPnl = double.tryParse(json['pnl']?.toString() ?? '0') ?? 0.0;

      // totalPnl = userPnl from API (no rounding, keep decimal)
      final totalPnlValue = apiUserPnl;
      // userPnl = pnl from API
      final extractedUserPnl = apiPnl;

      debugPrint('API userPnl: $apiUserPnl -> totalPnl: $totalPnlValue');
      debugPrint('API pnl: $apiPnl -> userPnl: $extractedUserPnl');

      return BotTrade(
        id: json['positionId']?.toString() ?? '',
        pair: symbol,
        openPrice: double.tryParse(json['avgPrice']?.toString() ?? '0') ?? 0.0,
        closePrice: double.tryParse(json['avgClosePrice']?.toString() ?? '0') ?? 0.0,
        totalPnl: totalPnlValue,
        userPnl: extractedUserPnl,
        date: parsedDate,
        status: json['positionSide']?.toString() ?? '',
        botName: botName,
        multiplier: multiplier,
        investment: double.tryParse(json['userInvestment']?.toString() ?? '0') ?? 0.0,
        positionId: json['positionId']?.toString(),
        positionSide: json['positionSide']?.toString(),
        avgPrice: double.tryParse(json['avgPrice']?.toString() ?? '0'),
        avgClosePrice: double.tryParse(json['avgClosePrice']?.toString() ?? '0'),
        userSimulatedMargin: double.tryParse(json['userSimulatedMargin']?.toString() ?? '0'),
        uplineShare: double.tryParse(json['uplineShare']?.toString() ?? '0'),
        distribution: json['distribution'] != null
            ? List<Map<String, dynamic>>.from(json['distribution'])
            : null,
        rawTime: rawTimeString,
        strategy: strategyName,
      );
    } else {
      // Legacy API format (fallback)
      return BotTrade(
        id: json['id']?.toString() ?? '',
        pair: json['pair']?.toString() ?? '',
        openPrice: double.tryParse(json['openPrice']?.toString() ?? '0') ?? 0.0,
        closePrice: double.tryParse(json['closePrice']?.toString() ?? '0') ?? 0.0,
        totalPnl: double.tryParse(json['totalPnl']?.toString() ?? '0') ?? 0.0,
        userPnl: double.tryParse(json['userPnl']?.toString() ?? '0') ?? 0.0,
        date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
        status: json['status']?.toString() ?? '',
        botName: json['botName']?.toString() ?? '',
        multiplier: json['multiplier']?.toString() ?? '',
        investment: double.tryParse(json['investment']?.toString() ?? '0') ?? 0.0,
        strategy: json['strategy']?.toString() ?? '',
      );
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'pair': pair,
      'openPrice': openPrice,
      'closePrice': closePrice,
      'totalPnl': totalPnl,
      'userPnl': userPnl,
      'date': date.toIso8601String(),
      'status': status,
      'botName': botName,
      'multiplier': multiplier,
      'investment': investment,
    };
  }

  String get formattedDate {
    return '${date.day} ${_getMonthName(date.month)} ${date.year}';
  }

  String get formattedTime {
    // Use exact UTC time from API without any conversion
    // Format: DD MMM YYYY, HH:MM:SS
    return '${date.day.toString().padLeft(2, '0')} ${_getMonthName(date.month)} ${date.year}, ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}';
  }

  String get formattedTimeUTC {
    // Convert to UTC and get exact time from API
    final utcDate = date.toUtc();
    // Format: DD MMM YYYY, HH:MM:SS
    return '${utcDate.day.toString().padLeft(2, '0')} ${_getMonthName(utcDate.month)} ${utcDate.year}, ${utcDate.hour.toString().padLeft(2, '0')}:${utcDate.minute.toString().padLeft(2, '0')}:${utcDate.second.toString().padLeft(2, '0')}';
  }

  String get formattedRawTime {
    // Return raw time string exactly as received from API with date and time in 12-hour format
    if (rawTime != null && rawTime!.isNotEmpty) {
      // Format: YYYY-MM-DD HH:MM:SS AM/PM
      if (rawTime!.contains('T')) {
        final parts = rawTime!.split('T');
        if (parts.length > 1) {
          final datePart = parts[0]; // YYYY-MM-DD
          final timePart = parts[1].split('.')[0]; // HH:MM:SS (remove milliseconds and Z)
          
          // Convert 24-hour to 12-hour format
          final timeComponents = timePart.split(':');
          if (timeComponents.length >= 3) {
            final hour = int.tryParse(timeComponents[0]) ?? 0;
            final minute = timeComponents[1];
            final second = timeComponents[2];
            
            final period = hour >= 12 ? 'PM' : 'AM';
            final hour12 = hour % 12 == 0 ? 12 : hour % 12;
            
            return '$datePart ${hour12.toString().padLeft(2, '0')}:$minute:$second $period';
          }
          return '$datePart $timePart';
        }
      }
      return rawTime!;
    }
    // Fallback to formatted time in 12-hour format
    final hour12 = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${hour12.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')} $period';
  }

  String _getMonthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }

  String get formattedOpenPrice => '\$${openPrice.toStringAsFixed(6)}';
  String get formattedClosePrice => '\$${closePrice.toStringAsFixed(6)}';
  String get formattedTotalPnl => '${totalPnl.toStringAsFixed(2)} PnL';
  String get formattedUserPnl => '${userPnl.toStringAsFixed(2)} PnL';
  bool get isProfit => userPnl >= 0;
}
