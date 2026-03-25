import 'dart:convert';
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
  static const String baseUrl = 'http://13.235.89.109:8085';
  
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
      } else if (response.statusCode == 404) {
        // Fallback to trades data if positions endpoint doesn't exist
        debugPrint('Positions endpoint not found, falling back to trades data');
        return await _getPositionsFromTrades(strategy, symbol);
      } else {
        return {
          'success': false,
          'error': 'Server error: ${response.statusCode}',
        };
      }
    } catch (e) {
      debugPrint('Error fetching user bot positions: $e');
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
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
      
      return {
        'success': false,
        'error': 'Failed to fetch positions data from trades',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Error in fallback: $e',
      };
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
  }) async {
    try {
      final queryParams = <String, String>{
        if (strategy != null) 'strategy': strategy,
        if (symbol != null) 'symbol': symbol,
      };
      
      final uri = Uri.parse('$baseUrl/bot/v1/bingxTrade/user-trades')
          .replace(queryParameters: queryParams);
      
      final response = await http.get(
        uri,
        headers: await _getHeaders(),
      );
      
      debugPrint('User Bot Trades API Response Status: ${response.statusCode}');
      debugPrint('User Bot Trades API Response Body: ${response.body}');
      
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
  static Future<Map<String, dynamic>> getMockTradeHistory({
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
      final response = await http.post(
        Uri.parse('$baseUrl/bot/v1/api/subscriptions/subscribe'),
        headers: await _getHeaders(),
        body: json.encode({
          'plan': plan,
          if (price != null) 'price': price,
        }),
      );
      
      debugPrint('Subscription API Response Status: ${response.statusCode}');
      debugPrint('Subscription API Response Body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': data['success'] ?? false,
          'subscription': data['subscription'],
          'message': 'Subscription successful',
        };
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'error': errorData['message'] ?? 'Subscription failed',
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
      final response = await http.post(
        Uri.parse('$baseUrl/bot/v1/api/investments/invest'),
        headers: await _getHeaders(),
        body: json.encode({
          'botId': botId,
          'amount': amount,
          if (strategy != null) 'strategy': strategy,
        }),
      );
      
      debugPrint('Invest API Response Status: ${response.statusCode}');
      debugPrint('Invest API Response Body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': data['success'] ?? false,
          'investment': data['investment'],
          'message': data['message'] ?? 'Investment successful',
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
      return {
        'success': false,
        'error': 'Network error: $e',
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
          return {
            'success': true,
            'data': data['data'] ?? data,
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
          'name': 'John Doe',
          'email': 'john.doe@example.com',
          'totalInvestment': '5000',
          'totalProfit': '1250.50',
          'activeBots': 3,
          'subscription': 'Premium',
          'joinDate': '2024-01-15',
          'lastLogin': '2025-03-25',
        },
      };
      debugPrint('Returning Mock Data: $mockData');
      return mockData;
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
        // Handle success field as string or boolean
        final success = data['success'];
        final isSuccess = success == true || success == 'true';
        
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
        debugPrint('Strategy Performance Server Error: ${response.statusCode}');
        return {
          'success': false,
          'error': 'Server error: ${response.statusCode}',
        };
      }
    } catch (e) {
      debugPrint('=== STRATEGY PERFORMANCE EXCEPTION ===');
      debugPrint('Error fetching strategy performance: $e');
      // Return mock data on network error for testing
      final mockData = {
        'success': true,
        'data': {
          'rot': '18.45%',
          'winRate': '65.23%',
          'trades': '156',
          'volume': '1.2M',
          'drawdown': '12.34%',
          'followers': '892',
        },
      };
      debugPrint('Returning Strategy Mock Data: $mockData');
      return mockData;
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
        return {
          'success': data['success'] ?? false,
          'withdrawal': data['withdrawal'],
          'message': data['message'] ?? 'Withdrawal successful',
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
    this.positionId,
    this.positionSide,
    this.avgPrice,
    this.avgClosePrice,
    this.userSimulatedMargin,
    this.uplineShare,
    this.distribution,
  });

  factory BotTrade.fromJson(Map<String, dynamic> json) {
    // Handle new API structure
    if (json.containsKey('positionId')) {
      // New API format
      return BotTrade(
        id: json['positionId']?.toString() ?? '',
        pair: json['symbol']?.toString() ?? '',
        openPrice: double.tryParse(json['avgPrice']?.toString() ?? '0') ?? 0.0,
        closePrice: double.tryParse(json['avgClosePrice']?.toString() ?? '0') ?? 0.0,
        totalPnl: double.tryParse(json['pnl']?.toString() ?? '0') ?? 0.0,
        userPnl: double.tryParse(json['pnl']?.toString() ?? '0') ?? 0.0,
        date: DateTime.tryParse(json['time']?.toString() ?? '') ?? DateTime.now(),
        status: json['positionSide']?.toString() ?? '',
        botName: json['strategy']?.toString() ?? '',
        multiplier: '2x', // Default, can be extracted from strategy name
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
