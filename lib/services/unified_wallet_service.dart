import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';
import 'spot_service.dart';
import 'spot_socket_service.dart';
import 'socket_service.dart';
import '../constants/api_config.dart';

/// Unified Wallet Balance Model
class WalletBalance {
  final Map<String, dynamic>? mainBalance;
  final double spotBalance;
  final double p2pBalance;
  final double demoBalance;
  final double botBalance;
  final Map<String, dynamic> spotAssets;
  final DateTime timestamp;

  WalletBalance({
    this.mainBalance,
    this.spotBalance = 0.0,
    this.p2pBalance = 0.0,
    this.demoBalance = 0.0,
    this.botBalance = 0.0,
    this.spotAssets = const {},
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory WalletBalance.fromJson(Map<String, dynamic> json) {
    return WalletBalance(
      mainBalance: json['mainBalance'] as Map<String, dynamic>?,
      spotBalance: (json['spotBalance'] as num?)?.toDouble() ?? 0.0,
      p2pBalance: (json['p2pBalance'] as num?)?.toDouble() ?? 0.0,
      demoBalance: (json['demoBalance'] as num?)?.toDouble() ?? 0.0,
      botBalance: (json['botBalance'] as num?)?.toDouble() ?? 0.0,
      spotAssets: json['spotAssets'] as Map<String, dynamic>? ?? {},
      timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'mainBalance': mainBalance,
      'spotBalance': spotBalance,
      'p2pBalance': p2pBalance,
      'demoBalance': demoBalance,
      'botBalance': botBalance,
      'spotAssets': spotAssets,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  WalletBalance copyWith({
    Map<String, dynamic>? mainBalance,
    double? spotBalance,
    double? p2pBalance,
    double? demoBalance,
    double? botBalance,
    Map<String, dynamic>? spotAssets,
    DateTime? timestamp,
    bool preserveSpotBalance = false,
    bool preserveBotBalance = false,
  }) {
    return WalletBalance(
      mainBalance: mainBalance ?? this.mainBalance,
      spotBalance: preserveSpotBalance ? this.spotBalance : (spotBalance ?? this.spotBalance),
      p2pBalance: p2pBalance ?? this.p2pBalance,
      demoBalance: demoBalance ?? this.demoBalance,
      botBalance: preserveBotBalance ? this.botBalance : (botBalance ?? this.botBalance),
      spotAssets: spotAssets ?? this.spotAssets,
      timestamp: timestamp ?? DateTime.now(),
    );
  }

  double get totalBalance {
    double mainUSDT = 0.0;
    if (mainBalance != null) {
      final usdt = mainBalance!['USDT'] ?? mainBalance!['usdt'];
      if (usdt is num) mainUSDT = usdt.toDouble();
      else if (usdt is Map) mainUSDT = double.tryParse(usdt['total']?.toString() ?? usdt['available']?.toString() ?? usdt['free']?.toString() ?? '0') ?? 0.0;
      else if (usdt is String) mainUSDT = double.tryParse(usdt) ?? 0.0;
    }
    
    return mainUSDT + 
      spotBalance + 
      p2pBalance + 
      demoBalance + 
      botBalance;
  }

  double get totalEquityUSDT {
    double inrBalance = 0.0;
    if (mainBalance != null) {
      final val = mainBalance!['INR'] ?? mainBalance!['inr'];
      if (val is num) inrBalance = val.toDouble();
      else if (val is String) inrBalance = double.tryParse(val) ?? 0.0;
    }
    return totalBalance + (inrBalance / 90.0);
  }
}

/// Coin Balance Model
class CoinBalance {
  final String asset;
  final double free;
  final double locked;

  CoinBalance({
    required this.asset,
    this.free = 0.0,
    this.locked = 0.0,
  });

  factory CoinBalance.fromJson(Map<String, dynamic> json) {
    return CoinBalance(
      asset: json['asset']?.toString().toUpperCase() ?? '',
      free: double.tryParse(json['free']?.toString() ?? '0') ?? 0.0,
      locked: double.tryParse(json['locked']?.toString() ?? '0') ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'asset': asset,
      'free': free,
      'locked': locked,
    };
  }

  double get total => free + locked;
}

/// Unified Wallet Service - Manages all wallet balances across different services
class UnifiedWalletService {
  static String get _baseUrl => 'https://api11.hathmetech.com/api';

  // State
  static WalletBalance? _walletBalance;
  static List<CoinBalance> _coinBalance = [];
  static double _botINRBalance = 0.0; // From bot wallet API
  static bool _isInitialized = false;
  static bool _isLoading = false;
  static String? _lastError;

  // Streams
  static final StreamController<WalletBalance?> _walletBalanceController = 
      StreamController<WalletBalance?>.broadcast();
  static final StreamController<List<CoinBalance>> _coinBalanceController = 
      StreamController<List<CoinBalance>>.broadcast();
  static final StreamController<bool> _loadingController = 
      StreamController<bool>.broadcast();
  static final StreamController<String?> _errorController = 
      StreamController<String?>.broadcast();

  // Socket subscriptions
  static StreamSubscription? _walletSocketSubscription;
  static StreamSubscription? _spotSocketSubscription;

  // Public getters
  static WalletBalance? get walletBalance => _walletBalance;
  static List<CoinBalance> get coinBalance => List.unmodifiable(_coinBalance);
  static bool get isLoading => _isLoading;
  static String? get lastError => _lastError;

  // Convenience getters for specific balances
  static double get mainUSDTBalance => _extractUSDTValue(_walletBalance?.mainBalance);
  static double get mainINRBalance {
    final main = _walletBalance?.mainBalance;
    debugPrint('mainINRBalance getter: _walletBalance=$_walletBalance');
    debugPrint('mainINRBalance getter: mainBalance=$main (type: ${main?.runtimeType})');
    final result = _extractINRValue(main);
    debugPrint('mainINRBalance getter: returning $result');
    return result;
  }

  static double get mainINRAvailableBalance {
    final main = _walletBalance?.mainBalance;
    return _extractINRAvailableValue(main);
  }
  static double get spotUSDTBalance => _walletBalance?.spotBalance ?? 0.0;
  static double get p2pUSDTBalance => _walletBalance?.p2pBalance ?? 0.0;
  static double get demoUSDTBalance => _walletBalance?.demoBalance ?? 0.0;
  static double get botUSDTBalance => _walletBalance?.botBalance ?? 0.0;
  static double get botINRBalance => _botINRBalance;
  
  // Total INR from mainBalance (socket/API) + spot coin + bot INR
  static double get totalINRBalance {
    double total = mainINRBalance; // Primary: mainBalance.INR from wallet socket/API
    
    // Add INR from spot coin balances (if any)
    final spotINR = getCoinBalance('INR');
    if (spotINR != null) {
      total += spotINR.total;
    }
    
    // Add INR from bot wallet (if any)
    total += _botINRBalance;
    
    debugPrint('totalINRBalance: mainINR=$mainINRBalance, spot=${spotINR?.total ?? 0}, bot=$_botINRBalance, total=$total');
    return total;
  }
  
  static double get totalUSDTBalance => _walletBalance?.totalBalance ?? 0.0;
  static double get totalEquityUSDT => _walletBalance?.totalEquityUSDT ?? 0.0;

  // Get specific coin balance
  static CoinBalance? getCoinBalance(String asset) {
    try {
      return _coinBalance.firstWhere((c) => c.asset.toUpperCase() == asset.toUpperCase());
    } catch (e) {
      return null;
    }
  }

  // Get USDT coin balance details
  static CoinBalance? get usdtCoinBalance => getCoinBalance('USDT');

  // INR holding getter (always 0 — endpoint no longer used)
  static double get inrHolding => 0.0;

  // Public streams
  static Stream<WalletBalance?> get walletBalanceStream => _walletBalanceController.stream;
  static Stream<List<CoinBalance>> get coinBalanceStream => _coinBalanceController.stream;
  static Stream<bool> get loadingStream => _loadingController.stream;
  static Stream<String?> get errorStream => _errorController.stream;

  // Initialization
  static Future<void> initialize() async {
    if (_isInitialized) return;

    debugPrint('UnifiedWalletService: Initializing...');

    // Load cached data
    await _loadCachedData();

    // Setup socket listeners
    _setupSocketListeners();

    // Fetch initial data
    await refreshAllBalances();

    _isInitialized = true;
    debugPrint('UnifiedWalletService: Initialized');
  }

  // Cleanup
  static void dispose() {
    debugPrint('UnifiedWalletService: Disposing...');
    
    _walletSocketSubscription?.cancel();
    _spotSocketSubscription?.cancel();
    
    _walletBalanceController.close();
    _coinBalanceController.close();
    _loadingController.close();
    _errorController.close();
    
    _isInitialized = false;
    debugPrint('UnifiedWalletService: Disposed');
  }

  // Clear state on logout
  static Future<void> clearState() async {
    debugPrint('UnifiedWalletService: Clearing state...');
    
    _walletBalance = null;
    _coinBalance = [];
    _lastError = null;
    
    // Clear cache
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('unified_wallet_balance');
    await prefs.remove('unified_coin_balance');
    
    // Notify listeners
    _walletBalanceController.add(null);
    _coinBalanceController.add([]);
    
    debugPrint('UnifiedWalletService: State cleared');
  }

  // Setup socket listeners
  static void _setupSocketListeners() {
    // Wallet socket - for mainBalance, p2pBalance, demoBalance
    _walletSocketSubscription?.cancel();
    _walletSocketSubscription = SocketService.balanceStream.listen(
      _handleWalletSocketUpdate,
      onError: (error) => debugPrint('Wallet socket error: $error'),
    );

    // Spot socket - for spot balance updates
    _spotSocketSubscription?.cancel();
    _spotSocketSubscription = SpotSocketService.balanceStream.listen(
      _handleSpotSocketUpdate,
      onError: (error) => debugPrint('Spot socket error: $error'),
    );
    
    // Ensure spot socket is subscribed to user channels
    SpotSocketService.subscribeUserChannels();
  }

  // Handle wallet socket updates
  static void _handleWalletSocketUpdate(Map<String, dynamic> data) {
    debugPrint('UnifiedWalletService: Wallet socket update received: $data');
    
    try {
      final event = data['event'] ?? data['type'];
      
      // Also process if it looks like a wallet summary (has mainBalance, botBalance etc)
      if (event == 'balance_update' || event == 'balance' || event == 'wallet_summary' || event == 'wallet_summary_update' || data.containsKey('mainBalance')) {
        final balanceData = data['data'] ?? data;
        
        // Extract wallet balances
        var mainBalance = balanceData['mainBalance'] ?? balanceData['main'];
        final p2pBalance = _extractUSDTValue(balanceData['p2pBalance'] ?? balanceData['p2p']);
        final demoBalance = _extractUSDTValue(balanceData['demoBalance'] ?? balanceData['demo'] ?? balanceData['demo_bot']);
        final botBalance = _extractUSDTValue(balanceData['botBalance'] ?? balanceData['bot']);
        
        _walletBalance = (_walletBalance ?? WalletBalance()).copyWith(
          mainBalance: mainBalance != null ? Map<String, dynamic>.from(mainBalance as Map) : null,
          p2pBalance: p2pBalance,
          demoBalance: demoBalance,
          botBalance: botBalance > 0 ? botBalance : null, // Only update if > 0 to preserve existing
          preserveSpotBalance: true,
        );
        
        debugPrint('UnifiedWalletService: mainBalance content: ${_walletBalance?.mainBalance}');
        debugPrint('UnifiedWalletService: mainBalance keys: ${_walletBalance?.mainBalance?.keys.toList()}');
        debugPrint('UnifiedWalletService: Extracted mainINRBalance: $mainINRBalance');
        
        _saveCachedData();
        _walletBalanceController.add(_walletBalance);
      }
    } catch (e) {
      debugPrint('UnifiedWalletService: Error handling wallet socket update: $e');
    }
  }

  // Handle spot socket updates
  static void _handleSpotSocketUpdate(Map<String, dynamic> data) {
    debugPrint('UnifiedWalletService: Spot socket update received: $data');
    
    try {
      final event = data['event'] ?? data['type'];
      
      if (event == 'balance_update' || event == 'balance') {
        final balanceData = data['data'] ?? data;
        
        // Update coin balances
        if (balanceData['assets'] != null) {
          _updateCoinBalancesFromAssets(balanceData['assets']);
        }
        
        // Extract USDT free balance for spotBalance
        final usdtFree = _extractUSDTFreeFromAssets(balanceData['assets']);
        
        // Update spot balance
        _walletBalance = (_walletBalance ?? WalletBalance()).copyWith(
          spotBalance: usdtFree,
        );
        
        _saveCachedData();
        _walletBalanceController.add(_walletBalance);
        
        debugPrint('UnifiedWalletService: Spot balance updated via socket: $usdtFree');
      }
    } catch (e) {
      debugPrint('UnifiedWalletService: Error handling spot socket update: $e');
    }
  }

  // Refresh all balances (called on login)
  static Future<void> refreshAllBalances() async {
    await Future.wait([
      refreshSpotBalance(),
      refreshBotBalance(),
    ]);
    
    // Wallet summary is refreshed via socket, but also call API as backup
    await refreshWalletSummary();
  }

  // 1. Get all wallet summary from wallet API
  static Future<Map<String, dynamic>> refreshWalletSummary() async {
    _setLoading(true);
    
    try {
      final result = await _getAllWalletSummary();
      debugPrint('refreshWalletSummary: API result=$result');
      
      if (result['success'] == true) {
        final data = result['data'] ?? {};
        debugPrint('refreshWalletSummary: data=$data');
        
        // Extract balances - DO NOT override spot or bot (merge rule)
        final mainData = data['main'] ?? data['mainBalance'];
        debugPrint('refreshWalletSummary: mainData=$mainData (type: ${mainData?.runtimeType})');
        final p2pData = _extractUSDTValue(data['p2p'] ?? data['p2pBalance']);
        final demoData = _extractUSDTValue(data['demo'] ?? data['demoBalance'] ?? data['demo_bot']);
        
        // Extract spot_assets from all-wallet-balance API (if available)
        final spotAssets = data['spot_assets'] as Map<String, dynamic>? ?? {};
        debugPrint('UnifiedWalletService: spot_assets raw data: ${data['spot_assets']}');
        debugPrint('UnifiedWalletService: spotAssets parsed count: ${spotAssets.length}');
        if (spotAssets.isNotEmpty) {
          debugPrint('UnifiedWalletService: Found ${spotAssets.length} spot assets: ${spotAssets.keys.toList()}');
          // Also populate _coinBalances from spot_assets so all tokens show
          _updateCoinBalancesFromAssets(spotAssets);
        }
        
        _walletBalance = (_walletBalance ?? WalletBalance()).copyWith(
          mainBalance: mainData != null ? _normalizeBalance(mainData) : null,
          p2pBalance: p2pData,
          demoBalance: demoData,
          spotAssets: spotAssets,
          preserveSpotBalance: true,
          preserveBotBalance: true,
        );
        
        debugPrint('refreshWalletSummary: _walletBalance updated with mainBalance=${_walletBalance?.mainBalance}');
        debugPrint('refreshWalletSummary: mainINRBalance=${mainINRBalance}');
        
        _saveCachedData();
        _walletBalanceController.add(_walletBalance);
        _setError(null);
        
        debugPrint('UnifiedWalletService: Wallet summary refreshed');
        return {'success': true, 'data': _walletBalance!.toJson()};
      } else {
        _setError(result['error'] ?? 'Failed to fetch wallet summary');
        return result;
      }
    } catch (e) {
      _setError('Failed to fetch wallet data, try again later!');
      return {'success': false, 'error': e.toString()};
    } finally {
      _setLoading(false);
    }
  }

  // 2. Get spot coins balance
  static Future<Map<String, dynamic>> refreshSpotBalance() async {
    _setLoading(true);
    
    try {
      final result = await SpotService.getBalance(forceRefresh: true);
      
      if (result['success'] == true) {
        final data = result['data'] ?? {};
        
        // Update coin balances
        if (data['raw_assets'] != null) {
          _updateCoinBalancesFromAssets(data['raw_assets']);
        } else if (data['assets'] != null) {
          _updateCoinBalancesFromAssets(data['assets']);
        }
        
        // Extract USDT free balance
        final assets = data['assets'] as Map<String, dynamic>? ?? {};
        final usdtData = assets['USDT'] as Map<String, dynamic>? ?? {};
        final usdtFree = usdtData['free'] ?? usdtData['available'] ?? 0.0;
        
        // Parse spot_assets from API response if available
        final spotAssets = data['spot_assets'] as Map<String, dynamic>? ?? {};
        
        _walletBalance = (_walletBalance ?? WalletBalance()).copyWith(
          spotBalance: usdtFree is num ? usdtFree.toDouble() : 0.0,
          spotAssets: spotAssets,
        );
        
        _saveCachedData();
        _walletBalanceController.add(_walletBalance);
        _coinBalanceController.add(List.unmodifiable(_coinBalance));
        _setError(null);
        
        debugPrint('UnifiedWalletService: Spot balance refreshed: $usdtFree, spotAssets: ${spotAssets.length}');
        return {'success': true, 'data': {'spotBalance': usdtFree, 'coins': _coinBalance.map((c) => c.toJson()).toList(), 'spotAssets': spotAssets}};
      } else {
        _setError(result['error'] ?? 'Failed to fetch spot balance');
        return result;
      }
    } catch (e) {
      _setError('Failed to fetch wallet data, try again later!');
      return {'success': false, 'error': e.toString()};
    } finally {
      _setLoading(false);
    }
  }

  // 3. Get bot wallet balance
  static Future<Map<String, dynamic>> refreshBotBalance() async {
    _setLoading(true);
    
    try {
      final result = await _getBotWalletBalance();
      
      if (result['success'] == true) {
        final data = result['data'] ?? {};
        final balance = data['balance'] ?? data['availableBalance'] ?? data['totalBalance'] ?? 0.0;
        final inrBalance = data['inrBalance'] ?? 0.0;
        
        _walletBalance = (_walletBalance ?? WalletBalance()).copyWith(
          botBalance: balance is num ? balance.toDouble() : 0.0,
        );
        
        _botINRBalance = inrBalance is num ? inrBalance.toDouble() : 0.0;
        
        _saveCachedData();
        _walletBalanceController.add(_walletBalance);
        _setError(null);
        
        debugPrint('UnifiedWalletService: Bot balance refreshed: $balance, Bot INR: $_botINRBalance');
        return {'success': true, 'data': {'botBalance': balance, 'botINR': _botINRBalance}};
      } else {
        _setError(result['error'] ?? 'Failed to fetch bot balance');
        return result;
      }
    } catch (e) {
      _setError('Failed to fetch wallet data, try again later!');
      return {'success': false, 'error': e.toString()};
    } finally {
      _setLoading(false);
    }
  }

  // After subscription - must refresh bot wallet
  static Future<void> refreshAfterSubscription() async {
    debugPrint('UnifiedWalletService: Refreshing after subscription...');
    await refreshBotBalance();
  }

  // Private API methods
  static Future<Map<String, String>> _getHeaders() async {
    final token = await AuthService.getToken();
    final userId = await _getUserId();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      'X-User-Id': userId,
    };
  }

  static Future<String> _getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_id') ?? '1';
  }

  static Future<Map<String, dynamic>> _getAllWalletSummary() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/wallet/v1/wallet/all-wallet-balance'),
        headers: await _getHeaders(),
      );

      debugPrint('Wallet Summary API: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return {'success': true, 'data': data['data'] ?? data};
        }
      }

      return {'success': false, 'error': 'Failed to fetch wallet summary'};
    } catch (e) {
      debugPrint('Error fetching wallet summary: $e');
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> _getBotWalletBalance() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/bot/v1/api/botwallet/balance'),
        headers: await _getHeaders(),
      );
      
      debugPrint('Bot Wallet API: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Handle different response structures
        if (data['success'] == true || data['balance'] != null || data['inr'] != null) {
          final balanceData = data['data'] ?? data;
          
          // Extract USDT balance
          double usdtBalance = 0.0;
          if (balanceData['balance'] != null) {
            usdtBalance = balanceData['balance'] is num ? balanceData['balance'].toDouble() : 0.0;
          } else if (balanceData['availableBalance'] != null) {
            usdtBalance = balanceData['availableBalance'] is num ? balanceData['availableBalance'].toDouble() : 0.0;
          } else if (balanceData['usdt'] != null) {
            final usdt = balanceData['usdt'];
            if (usdt is num) usdtBalance = usdt.toDouble();
            else if (usdt is Map) usdtBalance = usdt['free'] ?? usdt['available'] ?? usdt['balance'] ?? 0.0;
          }
          
          // Extract INR balance
          double inrBalance = 0.0;
          if (balanceData['inr'] != null) {
            final inr = balanceData['inr'];
            if (inr is num) inrBalance = inr.toDouble();
            else if (inr is Map) inrBalance = inr['free'] ?? inr['available'] ?? inr['balance'] ?? inr['total'] ?? 0.0;
          } else if (balanceData['INR'] != null) {
            final inr = balanceData['INR'];
            if (inr is num) inrBalance = inr.toDouble();
            else if (inr is Map) inrBalance = inr['free'] ?? inr['available'] ?? inr['balance'] ?? inr['total'] ?? 0.0;
          }
          
          return {
            'success': true,
            'data': {
              'balance': usdtBalance,
              'availableBalance': balanceData['availableBalance'] ?? usdtBalance,
              'totalBalance': balanceData['totalBalance'] ?? usdtBalance,
              'inrBalance': inrBalance,
            }
          };
        }
        return {'success': false, 'error': data['message'] ?? 'Failed to fetch bot balance'};
      }
      return {'success': false, 'error': 'Server error: ${response.statusCode}'};
    } catch (e) {
      debugPrint('Error fetching bot wallet balance: $e');
      return {'success': false, 'error': 'Network error: $e'};
    }
  }


  // Helper methods
  static double _extractUSDTValue(dynamic data) {
    if (data == null) return 0.0;
    
    if (data is num) return data.toDouble();
    
    if (data is Map) {
      // 1. Check direct keys for USDT (flat map)
      final directUsdt = data['USDT'] ?? data['usdt'];
      if (directUsdt != null) {
        return _parseBalanceField(directUsdt, preferTotal: true);
      }

      // 2. Check for USDT in balances list
      final balances = data['balances'];
      if (balances is List) {
        for (var b in balances) {
          if (b is Map && (b['coin']?.toString().toUpperCase() == 'USDT' || b['asset']?.toString().toUpperCase() == 'USDT')) {
            return _parseBalanceField(b, preferTotal: true);
          }
        }
      }
      
      // 3. Check for USDT in balances map
      if (balances is Map) {
        final usdt = balances['USDT'] ?? balances['usdt'];
        if (usdt != null) {
          return _parseBalanceField(usdt, preferTotal: true);
        }
      }
      
      // 4. Check for common fields at top level
      final commonFields = ['total', 'balance', 'available', 'free', 'availableBalance', 'totalBalance'];
      for (var field in commonFields) {
        if (data[field] != null) {
          return double.tryParse(data[field].toString()) ?? 0.0;
        }
      }
    }
    
    return 0.0;
  }

  static double _extractINRValue(dynamic data) {
    debugPrint('_extractINRValue: called with data=$data (type: ${data.runtimeType})');
    if (data == null) {
      debugPrint('_extractINRValue: data is null, returning 0.0');
      return 0.0;
    }
    if (data is num) {
      debugPrint('_extractINRValue: data is num, returning ${data.toDouble()}');
      return data.toDouble();
    }
    
    if (data is Map) {
      debugPrint('_extractINRValue: data is Map with keys: ${data.keys.toList()}');
      // 1. Check direct keys for INR (flat map)
      final directInr = data['INR'] ?? data['inr'] ?? data['Inr'];
      debugPrint('_extractINRValue: directInr=$directInr (type: ${directInr?.runtimeType})');
      if (directInr != null) {
        final result = _parseBalanceField(directInr, preferTotal: true);
        debugPrint('_extractINRValue: parsed result=$result');
        return result;
      }

      // 2. Check for INR in balances list
      final balances = data['balances'];
      if (balances is List) {
        for (var b in balances) {
          if (b is Map && (b['coin']?.toString().toUpperCase() == 'INR' || b['asset']?.toString().toUpperCase() == 'INR')) {
            return _parseBalanceField(b, preferTotal: true);
          }
        }
      }
      
      // 3. Check for INR in balances map
      if (balances is Map) {
        final inr = balances['INR'] ?? balances['inr'] ?? balances['Inr'];
        if (inr != null) {
          return _parseBalanceField(inr, preferTotal: true);
        }
      }
      debugPrint('_extractINRValue: INR not found in any format');
    }
    debugPrint('_extractINRValue: returning 0.0 (data type: ${data.runtimeType})');
    return 0.0;
  }

  static double _extractINRAvailableValue(dynamic data) {
    if (data == null) return 0.0;
    if (data is num) return data.toDouble();
    
    if (data is Map) {
      // 1. Check direct keys for INR (flat map)
      final directInr = data['INR'] ?? data['inr'] ?? data['Inr'];
      if (directInr != null) {
        return _parseBalanceField(directInr, preferTotal: false);
      }

      // 2. Check for INR in balances list
      final balances = data['balances'];
      if (balances is List) {
        for (var b in balances) {
          if (b is Map && (b['coin']?.toString().toUpperCase() == 'INR' || b['asset']?.toString().toUpperCase() == 'INR')) {
            return _parseBalanceField(b, preferTotal: false);
          }
        }
      }
      
      // 3. Check for INR in balances map
      if (balances is Map) {
        final inr = balances['INR'] ?? balances['inr'] ?? balances['Inr'];
        if (inr != null) {
          return _parseBalanceField(inr, preferTotal: false);
        }
      }
    }
    return 0.0;
  }

  static double _parseBalanceField(dynamic val, {bool preferTotal = true}) {
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? 0.0;
    if (val is Map) {
      if (preferTotal) {
        final total = val['total'] ?? val['balance'] ?? val['totalBalance'] ?? val['available'] ?? val['free'] ?? val['availableBalance'] ?? 0.0;
        return double.tryParse(total.toString()) ?? 0.0;
      } else {
        final available = val['available'] ?? val['free'] ?? val['availableBalance'] ?? val['total'] ?? val['balance'] ?? val['totalBalance'] ?? 0.0;
        return double.tryParse(available.toString()) ?? 0.0;
      }
    }
    return 0.0;
  }

  static Map<String, dynamic> _normalizeBalance(dynamic data) {
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return {};
  }

  static void _updateCoinBalancesFromAssets(dynamic assets) {
    if (assets is List) {
      _coinBalance = assets.map((asset) {
        if (asset is Map) {
          return CoinBalance.fromJson(Map<String, dynamic>.from(asset));
        }
        return CoinBalance(asset: '');
      }).where((c) => c.asset.isNotEmpty).toList();
    } else if (assets is Map) {
      _coinBalance = assets.entries.map((entry) {
        final assetName = entry.key.toString().toUpperCase();
        final assetData = entry.value;
        if (assetData is Map) {
          return CoinBalance(
            asset: assetName,
            free: double.tryParse(assetData['free']?.toString() ?? assetData['available']?.toString() ?? '0') ?? 0.0,
            locked: double.tryParse(assetData['locked']?.toString() ?? '0') ?? 0.0,
          );
        }
        return CoinBalance(asset: assetName);
      }).where((c) => c.asset.isNotEmpty).toList();
    }
  }

  static double _extractUSDTFreeFromAssets(dynamic assets) {
    if (assets is List) {
      for (final asset in assets) {
        if (asset is Map) {
          final assetName = asset['asset']?.toString().toUpperCase() ?? '';
          if (assetName == 'USDT') {
            return double.tryParse(asset['free']?.toString() ?? asset['available']?.toString() ?? '0') ?? 0.0;
          }
        }
      }
    } else if (assets is Map) {
      final usdtData = assets['USDT'] ?? assets['usdt'];
      if (usdtData is Map) {
        return double.tryParse(usdtData['free']?.toString() ?? usdtData['available']?.toString() ?? '0') ?? 0.0;
      }
    }
    return 0.0;
  }

  static void _setLoading(bool loading) {
    _isLoading = loading;
    _loadingController.add(loading);
  }

  static void _setError(String? error) {
    _lastError = error;
    _errorController.add(error);
  }

  static Future<void> _loadCachedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final walletData = prefs.getString('unified_wallet_balance');
      if (walletData != null) {
        _walletBalance = WalletBalance.fromJson(json.decode(walletData));
      }
      
      final coinData = prefs.getString('unified_coin_balance');
      if (coinData != null) {
        final List<dynamic> list = json.decode(coinData);
        _coinBalance = list.map((e) => CoinBalance.fromJson(e)).toList();
      }
      
      debugPrint('UnifiedWalletService: Loaded cached data');
    } catch (e) {
      debugPrint('UnifiedWalletService: Error loading cached data: $e');
    }
  }

  static Future<void> _saveCachedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      if (_walletBalance != null) {
        await prefs.setString('unified_wallet_balance', json.encode(_walletBalance!.toJson()));
      }
      
      if (_coinBalance.isNotEmpty) {
        await prefs.setString('unified_coin_balance', json.encode(_coinBalance.map((c) => c.toJson()).toList()));
      }
    } catch (e) {
      debugPrint('UnifiedWalletService: Error saving cached data: $e');
    }
  }
}

class ApiConfig {
  static String? get baseUrl => null;
}
