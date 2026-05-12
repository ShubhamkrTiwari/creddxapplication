import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

/// Binance Market Data Service
/// Provides real-time market data from Binance API and WebSocket streams
class BinanceService {
  static const String _baseUrl = 'https://api.binance.com';
  static const String _wsUrl = 'wss://stream.binance.com:9443';
  
  // WebSocket connections
  static final Map<String, WebSocketChannel> _channels = {};
  static final Map<String, StreamController<Map<String, dynamic>>> _streamControllers = {};
  
  /// Get 24hr ticker data for all symbols
  /// Returns list of all trading pairs with price, volume, change data
  static Future<List<Map<String, dynamic>>> get24hrTickerData() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/v3/ticker/24hr'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((item) => {
          'symbol': item['symbol'],
          'price': double.tryParse(item['lastPrice']?.toString() ?? '0') ?? 0.0,
          'priceChange': double.tryParse(item['priceChange']?.toString() ?? '0') ?? 0.0,
          'priceChangePercent': double.tryParse(item['priceChangePercent']?.toString() ?? '0') ?? 0.0,
          'volume': double.tryParse(item['volume']?.toString() ?? '0') ?? 0.0,
          'quoteVolume': double.tryParse(item['quoteVolume']?.toString() ?? '0') ?? 0.0,
          'highPrice': double.tryParse(item['highPrice']?.toString() ?? '0') ?? 0.0,
          'lowPrice': double.tryParse(item['lowPrice']?.toString() ?? '0') ?? 0.0,
          'openPrice': double.tryParse(item['openPrice']?.toString() ?? '0') ?? 0.0,
          'lastPrice': double.tryParse(item['lastPrice']?.toString() ?? '0') ?? 0.0,
          'weightedAvgPrice': double.tryParse(item['weightedAvgPrice']?.toString() ?? '0') ?? 0.0,
          'bidPrice': double.tryParse(item['bidPrice']?.toString() ?? '0') ?? 0.0,
          'askPrice': double.tryParse(item['askPrice']?.toString() ?? '0') ?? 0.0,
          'count': item['count'] ?? 0,
        }).toList();
      } else {
        throw Exception('Failed to fetch ticker data: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching Binance 24hr ticker: $e');
      return [];
    }
  }
  
  /// Get ticker data for a specific symbol
  static Future<Map<String, dynamic>?> getTickerData(String symbol) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/v3/ticker/24hr?symbol=$symbol'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final item = json.decode(response.body);
        return {
          'symbol': item['symbol'],
          'price': double.tryParse(item['lastPrice']?.toString() ?? '0') ?? 0.0,
          'priceChange': double.tryParse(item['priceChange']?.toString() ?? '0') ?? 0.0,
          'priceChangePercent': double.tryParse(item['priceChangePercent']?.toString() ?? '0') ?? 0.0,
          'volume': double.tryParse(item['volume']?.toString() ?? '0') ?? 0.0,
          'highPrice': double.tryParse(item['highPrice']?.toString() ?? '0') ?? 0.0,
          'lowPrice': double.tryParse(item['lowPrice']?.toString() ?? '0') ?? 0.0,
          'bidPrice': double.tryParse(item['bidPrice']?.toString() ?? '0') ?? 0.0,
          'askPrice': double.tryParse(item['askPrice']?.toString() ?? '0') ?? 0.0,
        };
      }
      return null;
    } catch (e) {
      print('Error fetching Binance ticker for $symbol: $e');
      return null;
    }
  }
  
  /// Get all USDT trading pairs
  static Future<List<Map<String, dynamic>>> getUSDTTradingPairs() async {
    final allTickers = await get24hrTickerData();
    return allTickers.where((ticker) {
      final symbol = ticker['symbol']?.toString() ?? '';
      return symbol.endsWith('USDT') && !symbol.contains('_');
    }).toList();
  }
  
  /// Connect to WebSocket for real-time ticker updates
  static Stream<Map<String, dynamic>>? connectTickerStream(String symbol) {
    try {
      // Close existing connection if any
      disconnectTickerStream(symbol);
      
      final streamUrl = '$_wsUrl/ws/${symbol.toLowerCase()}@ticker';
      final channel = WebSocketChannel.connect(Uri.parse(streamUrl));
      final controller = StreamController<Map<String, dynamic>>.broadcast();
      
      _channels[symbol] = channel;
      _streamControllers[symbol] = controller;
      
      channel.stream.listen(
        (message) {
          try {
            final data = json.decode(message);
            final parsedData = {
              'symbol': data['s'],
              'price': double.tryParse(data['c']?.toString() ?? '0') ?? 0.0,
              'priceChange': double.tryParse(data['p']?.toString() ?? '0') ?? 0.0,
              'priceChangePercent': double.tryParse(data['P']?.toString() ?? '0') ?? 0.0,
              'volume': double.tryParse(data['v']?.toString() ?? '0') ?? 0.0,
              'quoteVolume': double.tryParse(data['q']?.toString() ?? '0') ?? 0.0,
              'highPrice': double.tryParse(data['h']?.toString() ?? '0') ?? 0.0,
              'lowPrice': double.tryParse(data['l']?.toString() ?? '0') ?? 0.0,
              'openPrice': double.tryParse(data['o']?.toString() ?? '0') ?? 0.0,
              'bidPrice': double.tryParse(data['b']?.toString() ?? '0') ?? 0.0,
              'askPrice': double.tryParse(data['a']?.toString() ?? '0') ?? 0.0,
              'eventTime': data['E'],
            };
            controller.add(parsedData);
          } catch (e) {
            print('Error parsing WebSocket message for $symbol: $e');
          }
        },
        onError: (error) {
          print('WebSocket error for $symbol: $error');
        },
        onDone: () {
          print('WebSocket disconnected for $symbol');
        },
      );
      
      print('WebSocket connected for $symbol');
      return controller.stream;
    } catch (e) {
      print('Error connecting WebSocket for $symbol: $e');
      return null;
    }
  }
  
  /// Disconnect WebSocket for a specific symbol
  static void disconnectTickerStream(String symbol) {
    _channels[symbol]?.sink.close();
    _channels.remove(symbol);
    _streamControllers[symbol]?.close();
    _streamControllers.remove(symbol);
  }
  
  /// Connect to multiple symbols with combined stream
  static Stream<Map<String, dynamic>>? connectMultiTickerStream(List<String> symbols) {
    try {
      final streams = symbols.map((s) => '${s.toLowerCase()}@ticker').join('/');
      final streamUrl = '$_wsUrl/stream?streams=$streams';
      final channel = WebSocketChannel.connect(Uri.parse(streamUrl));
      final controller = StreamController<Map<String, dynamic>>.broadcast();
      
      channel.stream.listen(
        (message) {
          try {
            final data = json.decode(message);
            final tickerData = data['data'];
            if (tickerData != null) {
              final parsedData = {
                'symbol': tickerData['s'],
                'price': double.tryParse(tickerData['c']?.toString() ?? '0') ?? 0.0,
                'priceChange': double.tryParse(tickerData['p']?.toString() ?? '0') ?? 0.0,
                'priceChangePercent': double.tryParse(tickerData['P']?.toString() ?? '0') ?? 0.0,
                'volume': double.tryParse(tickerData['v']?.toString() ?? '0') ?? 0.0,
                'highPrice': double.tryParse(tickerData['h']?.toString() ?? '0') ?? 0.0,
                'lowPrice': double.tryParse(tickerData['l']?.toString() ?? '0') ?? 0.0,
                'bidPrice': double.tryParse(tickerData['b']?.toString() ?? '0') ?? 0.0,
                'askPrice': double.tryParse(tickerData['a']?.toString() ?? '0') ?? 0.0,
              };
              controller.add(parsedData);
            }
          } catch (e) {
            print('Error parsing multi-ticker message: $e');
          }
        },
        onError: (error) {
          print('Multi-ticker WebSocket error: $error');
        },
      );
      
      print('Multi-ticker WebSocket connected for ${symbols.length} symbols');
      return controller.stream;
    } catch (e) {
      print('Error connecting multi-ticker WebSocket: $e');
      return null;
    }
  }
  
  /// Get top trading pairs by volume
  static Future<List<Map<String, dynamic>>> getTopTradingPairs({int limit = 20}) async {
    final allPairs = await getUSDTTradingPairs();
    allPairs.sort((a, b) => (b['quoteVolume'] ?? 0.0).compareTo(a['quoteVolume'] ?? 0.0));
    return allPairs.take(limit).toList();
  }
  
  /// Disconnect all WebSocket connections
  static void disconnectAll() {
    for (final symbol in _channels.keys) {
      _channels[symbol]?.sink.close();
    }
    for (final controller in _streamControllers.values) {
      controller.close();
    }
    _channels.clear();
    _streamControllers.clear();
  }
  
  /// Get market cap data from CoinGecko
  static Future<Map<String, double>> getMarketCapData() async {
    try {
      // CoinGecko API - free tier
      final response = await http.get(
        Uri.parse('https://api.coingecko.com/api/v3/coins/markets?vs_currency=usd&order=market_cap_desc&per_page=100&page=1'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final Map<String, double> marketCaps = {};
        
        for (final item in data) {
          final symbol = item['symbol']?.toString().toUpperCase() ?? '';
          final marketCap = double.tryParse(item['market_cap']?.toString() ?? '0') ?? 0.0;
          if (symbol.isNotEmpty && marketCap > 0) {
            marketCaps[symbol] = marketCap;
          }
        }
        return marketCaps;
      } else {
        print('CoinGecko API error: ${response.statusCode}');
        return {};
      }
    } catch (e) {
      print('Error fetching market cap from CoinGecko: $e');
      return {};
    }
  }
  
  /// Get market cap for a specific symbol
  static double? getMarketCapForSymbol(String symbol, Map<String, double> marketCaps) {
    // Remove USDT suffix to get base symbol
    final baseSymbol = symbol.replaceAll('USDT', '');
    return marketCaps[baseSymbol];
  }
}
