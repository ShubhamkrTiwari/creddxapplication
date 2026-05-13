import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';
import 'socket_service.dart';
import 'spot_service.dart';
import 'spot_socket_service.dart';

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
    double? p2pINRBalance,
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
      if (usdt is num) {
        mainUSDT = usdt.toDouble();
      } else if (usdt is Map) {
        final val = usdt['total'] ?? usdt['balance'] ?? usdt['available'] ?? usdt['free'] ?? usdt['amount'] ?? '0';
        mainUSDT = double.tryParse(val.toString()) ?? 0.0;
      } else if (usdt is String) {
        mainUSDT = double.tryParse(usdt) ?? 0.0;
      }
    }

    // Total balance excludes demo balance (main + spot + p2p + bot only)
    return mainUSDT +
      spotBalance +
      p2pBalance +
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
  static String get _baseUrl => 'http://65.0.196.122:8085'; // Testing server

  // State
  static WalletBalance? _walletBalance;
  static List<CoinBalance> _coinBalance = [];
  static double _botINRBalance = 0.0; // From bot wallet API
  static bool _isInitialized = false;
  static bool _isLoading = false;
  static String? _lastError;
  static bool _isRefreshingSummary = false; // Guard against concurrent refreshes

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
  static bool get isInitialized => _isInitialized;
  static String? get lastError => _lastError;

  // Convenience getters for specific balances
  static double get mainUSDTBalance => _extractUSDTValue(_walletBalance?.mainBalance);
  static double get mainINRBalance {
    final main = _walletBalance?.mainBalance;
    final result = _extractINRValue(main);
    
    // Debug log if we have USDT but no INR
    if (result == 0.0 && main != null && main.isNotEmpty) {
      debugPrint('UnifiedWalletService: DISCREPANCY - mainBalance exists but INR is 0.0. Keys: ${main.keys.toList()}');
      debugPrint('UnifiedWalletService: mainBalance content: $main');
    }
    
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
    final mainInr = mainINRBalance; 
    double total = mainInr;
    
    // Add INR from spot coin balances (if any)
    final spotINR = getCoinBalance('INR');
    if (spotINR != null) {
      total += spotINR.total;
    }
    
    // Add INR from bot wallet (if any)
    total += _botINRBalance;
    
    if (total == 0.0) {
      debugPrint('UnifiedWalletService: totalINRBalance is 0.0. mainInr=$mainInr, bot=$_botINRBalance');
    }
    
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
    if (_isInitialized || _isLoading) return;

    _isLoading = true;
    debugPrint('UnifiedWalletService: Initializing...');

    try {
      // Load cached data
      await _loadCachedData();

      // Setup socket listeners
      _setupSocketListeners();

      // Fetch initial data
      await refreshAllBalances();

      _isInitialized = true;
      debugPrint('UnifiedWalletService: Initialized');
    } catch (e) {
      debugPrint('UnifiedWalletService: Initialization error: $e');
    } finally {
      _isLoading = false;
    }
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

    // Cancel existing socket subscriptions so stale data isn't processed
    _walletSocketSubscription?.cancel();
    _walletSocketSubscription = null;
    _spotSocketSubscription?.cancel();
    _spotSocketSubscription = null;

    // Reset all balance state
    _walletBalance = null;
    _coinBalance = [];
    _botINRBalance = 0.0;
    _lastError = null;

    // Reset init/loading flags so initialize() runs fully for the next user
    _isInitialized = false;
    _isLoading = false;

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
      
      // Only process as full wallet summary if it's the actual wallet summary event
      // Socket updates for individual balances should not trigger full wallet update
      if (event == 'wallet_summary' || event == 'wallet_summary_update') {
        
        final balanceData = data['data'] ?? data;
        
        // 1. Merge mainBalance instead of replacing it
        var mainBalanceData = balanceData['mainBalance'] ?? balanceData['main'] ?? balanceData['main_balance'];
        
        // Handle potential stringified JSON from socket
        if (mainBalanceData is String && mainBalanceData.trim().startsWith('{')) {
          try {
            mainBalanceData = json.decode(mainBalanceData);
          } catch (e) {
            debugPrint('UnifiedWalletService: Failed to decode mainBalanceData string: $e');
          }
        }

        Map<String, dynamic>? mergedMainBalance;

        if (mainBalanceData is Map) {
          final existingMain = _walletBalance?.mainBalance ?? {};
          mergedMainBalance = {...existingMain, ...Map<String, dynamic>.from(mainBalanceData)};
        } else if (mainBalanceData is List) {
          mergedMainBalance = _normalizeBalance(mainBalanceData);
        } else {
          // If mainBalance is not found as a sub-object, check if INR is at the top level
          final topLevelINR = _findINRRecursively(balanceData);
          if (topLevelINR > 0) {
            final existingMain = _walletBalance?.mainBalance ?? {};
            mergedMainBalance = {...existingMain, 'INR': topLevelINR};
            debugPrint('UnifiedWalletService: Found INR via deep scan: $topLevelINR');
          }
        }

        final p2pData = balanceData['p2pBalance'] ?? balanceData['p2p'];
        final demoData = balanceData['demoBalance'] ?? balanceData['demo'] ?? balanceData['demo_bot'];
        final botData = balanceData['botBalance'] ?? balanceData['bot'];
        
        final p2pBalance = p2pData != null ? _extractUSDTValue(p2pData) : _walletBalance?.p2pBalance ?? 0.0;
        final demoBalance = demoData != null ? _extractUSDTValue(demoData) : _walletBalance?.demoBalance ?? 0.0;
        final botBalance = botData != null ? _extractUSDTValue(botData) : _walletBalance?.botBalance ?? 0.0;
        
        // Directly construct to avoid copyWith issues
        _walletBalance = WalletBalance(
          mainBalance: mergedMainBalance ?? _walletBalance?.mainBalance,
          spotBalance: _walletBalance?.spotBalance ?? 0.0,
          p2pBalance: p2pBalance,
          demoBalance: demoBalance,
          botBalance: botBalance,
          spotAssets: _walletBalance?.spotAssets ?? const {},
        );

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
        
        // Update spot balance - preserve all other fields
        _walletBalance = WalletBalance(
          mainBalance: _walletBalance?.mainBalance,
          spotBalance: usdtFree,
          p2pBalance: _walletBalance?.p2pBalance ?? 0.0,
          demoBalance: _walletBalance?.demoBalance ?? 0.0,
          botBalance: _walletBalance?.botBalance ?? 0.0,
          spotAssets: _walletBalance?.spotAssets ?? const {},
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
    // Fetch all balances WITHOUT emitting to stream, then emit combined data once
    // This prevents showing partial data (e.g., only bot balance) while others load
    debugPrint('UnifiedWalletService: Starting refreshAllBalances (single emit mode)...');

    // Store current balance to preserve any existing data
    final existingMainBalance = _walletBalance?.mainBalance;
    final existingSpotBalance = _walletBalance?.spotBalance ?? 0.0;
    final existingP2pBalance = _walletBalance?.p2pBalance ?? 0.0;
    final existingDemoBalance = _walletBalance?.demoBalance ?? 0.0;
    final existingBotBalance = _walletBalance?.botBalance ?? 0.0;
    final existingSpotAssets = _walletBalance?.spotAssets ?? const {};

    double newSpotBalance = existingSpotBalance;
    double newP2pBalance = existingP2pBalance;
    double newDemoBalance = existingDemoBalance;
    double newBotBalance = existingBotBalance;
    Map<String, dynamic>? newMainBalance = existingMainBalance;
    Map<String, dynamic> newSpotAssets = Map<String, dynamic>.from(existingSpotAssets);

    // 1. Fetch bot balance
    try {
      final botResult = await _getBotWalletBalance();
      if (botResult['success'] == true) {
        final data = botResult['data'] ?? {};
        final balance = data['balance'] ?? data['availableBalance'] ?? data['totalBalance'] ?? 0.0;
        newBotBalance = balance is num ? balance.toDouble() : 0.0;
        debugPrint('UnifiedWalletService: Bot balance fetched: $newBotBalance');
      } else {
        debugPrint('UnifiedWalletService: Bot balance API failed: ${botResult['error']}');
      }
    } catch (e) {
      debugPrint('UnifiedWalletService: Error fetching bot balance: $e');
    }

    // 2. Fetch spot balance
    try {
      final spotResult = await SpotService.getBalance(forceRefresh: true);
      if (spotResult['success'] == true) {
        final data = spotResult['data'] ?? {};
        final assets = data['assets'] as Map<String, dynamic>? ?? {};
        final usdtData = assets['USDT'] as Map<String, dynamic>? ?? {};
        final usdtFree = usdtData['free'] ?? usdtData['available'] ?? 0.0;
        newSpotBalance = usdtFree is num ? usdtFree.toDouble() : 0.0;

        // Update spot assets
        final spotAssets = data['spot_assets'] as Map<String, dynamic>? ?? {};
        if (spotAssets.isNotEmpty) {
          newSpotAssets = Map<String, dynamic>.from(spotAssets);
        }

        // Update coin balances
        if (data['raw_assets'] != null) {
          _updateCoinBalancesFromAssets(data['raw_assets']);
        } else if (data['assets'] != null) {
          _updateCoinBalancesFromAssets(data['assets']);
        }

        debugPrint('UnifiedWalletService: Spot balance fetched: $newSpotBalance');
      }
    } catch (e) {
      debugPrint('UnifiedWalletService: Error fetching spot balance: $e');
    }

    // 3. Fetch wallet summary (main, p2p, demo, INR)
    try {
      final summaryResult = await _getAllWalletSummary();
      if (summaryResult['success'] == true) {
        final data = summaryResult['data'] ?? {};

        // Extract main balance
        var mainData = data['main'] ?? data['mainBalance'];
        final inrVal = _findINRRecursively(data);
        
        // Normalize mainData (handles both Map and List formats)
        Map<String, dynamic> normalizedMain = _normalizeBalance(mainData);
        
        if (inrVal > 0) {
          normalizedMain['INR'] = inrVal;
        }

        // Merge with existing main balance
        final existingMain = newMainBalance ?? {};
        newMainBalance = {...existingMain, ...normalizedMain};

        // Extract other balances
        final p2pData = _extractUSDTValue(data['p2p'] ?? data['p2pBalance']);
        final demoData = _extractUSDTValue(data['demo'] ?? data['demoBalance'] ?? data['demo_bot']);
        final botDataSummary = _extractUSDTValue(data['bot'] ?? data['botBalance']);

        if (p2pData > 0) newP2pBalance = p2pData;
        if (demoData > 0) newDemoBalance = demoData;

        // Spot from summary if not already set
        final summarySpot = _extractUSDTValue(data['spot'] ?? data['spotBalance']);
        if (summarySpot > 0 && newSpotBalance == 0) {
          newSpotBalance = summarySpot;
        }

        debugPrint('UnifiedWalletService: Wallet summary fetched - P2P: $newP2pBalance, Demo: $newDemoBalance');
      }
    } catch (e) {
      debugPrint('UnifiedWalletService: Error fetching wallet summary: $e');
    }

    // Build final combined wallet balance
    _walletBalance = WalletBalance(
      mainBalance: newMainBalance,
      spotBalance: newSpotBalance,
      p2pBalance: newP2pBalance,
      demoBalance: newDemoBalance,
      botBalance: newBotBalance,
      spotAssets: newSpotAssets,
    );

    // Save and emit ONCE with all combined data
    _saveCachedData();
    _walletBalanceController.add(_walletBalance);
    _coinBalanceController.add(List.unmodifiable(_coinBalance));

    debugPrint('UnifiedWalletService: refreshAllBalances complete - Total: ${_walletBalance?.totalBalance}, Main: $newMainBalance, Spot: $newSpotBalance, P2P: $newP2pBalance, Bot: $newBotBalance, Demo: $newDemoBalance');
  }

  // Update wallet data from login response (immediate update without API call)
  static Future<void> updateFromLoginData({
    Map<String, dynamic>? mainBalance,
    double? botBalance,
    double? p2pBalance,
    double? demoBalance,
    double? spotBalance,
  }) async {
    try {
      debugPrint('UnifiedWalletService: Updating from login data...');
      
      // Update wallet balance with login data
      _walletBalance = (_walletBalance ?? WalletBalance()).copyWith(
        mainBalance: mainBalance != null ? _normalizeBalance(mainBalance) : _walletBalance?.mainBalance,
        botBalance: botBalance ?? _walletBalance?.botBalance,
        p2pBalance: p2pBalance ?? _walletBalance?.p2pBalance,
        demoBalance: demoBalance ?? _walletBalance?.demoBalance,
        spotBalance: spotBalance ?? _walletBalance?.spotBalance,
      );
      
      // Save to cache
      await _saveCachedData();
      
      // Notify listeners
      _walletBalanceController.add(_walletBalance);
      
      debugPrint('UnifiedWalletService: Updated from login data - Main: ${_walletBalance?.mainBalance}, Bot: ${_walletBalance?.botBalance}, P2P: ${_walletBalance?.p2pBalance}, Spot: ${_walletBalance?.spotBalance}');
    } catch (e) {
      debugPrint('UnifiedWalletService: Error updating from login data: $e');
    }
  }

  // 1. Get all wallet summary from wallet API
  static Future<Map<String, dynamic>> refreshWalletSummary({bool emitToStream = true}) async {
    // Prevent concurrent refreshes that cause race conditions
    if (_isRefreshingSummary) {
      debugPrint('refreshWalletSummary: Already refreshing, skipping duplicate call');
      return {'success': false, 'error': 'Already refreshing'};
    }
    _isRefreshingSummary = true;
    _setLoading(true);
    
    try {
      final result = await _getAllWalletSummary();
      debugPrint('refreshWalletSummary: API result=$result');
      
      if (result['success'] == true) {
        final data = result['data'] ?? {};
        debugPrint('refreshWalletSummary: data=$data');
        
        // Extract balances - DO NOT override spot or bot (merge rule)
        var mainData = data['main'] ?? data['mainBalance'];
        
        // Extract INR using the new recursive deep scan for maximum reliability
        final inrVal = _findINRRecursively(data);
        if (inrVal > 0) {
          debugPrint('UnifiedWalletService: Found INR via deep scan in refreshWalletSummary: $inrVal');
          if (mainData == null) {
            mainData = {'INR': inrVal};
          } else if (mainData is Map) {
            mainData = {...Map<String, dynamic>.from(mainData), 'INR': inrVal};
          } else if (mainData is List) {
            final list = List<dynamic>.from(mainData);
            bool found = false;
            for (int i = 0; i < list.length; i++) {
              if (list[i] is Map && (list[i]['coin'] == 'INR' || list[i]['asset'] == 'INR')) {
                list[i] = {...Map<String, dynamic>.from(list[i]), 'balance': inrVal};
                found = true;
                break;
              }
            }
            if (!found) {
              list.add({'coin': 'INR', 'balance': inrVal, 'free': inrVal, 'available': inrVal});
            }
            mainData = list;
          }
        }

        final p2pData = _extractUSDTValue(data['p2p'] ?? data['p2pBalance']);
        final p2pINRData = _extractINRValue(data['p2p'] ?? data['p2pBalance']);
        final demoData = _extractUSDTValue(data['demo'] ?? data['demoBalance'] ?? data['demo_bot']);
        final botData = _extractUSDTValue(data['bot'] ?? data['botBalance']);
        final spotData = _extractUSDTValue(data['spot'] ?? data['spotBalance']);
        
        debugPrint('refreshWalletSummary: RAW p2pBalance=${data['p2pBalance']}, p2pData=$p2pData');
        debugPrint('refreshWalletSummary: RAW spotBalance=${data['spotBalance']}, spotData=$spotData');
        debugPrint('refreshWalletSummary: RAW botBalance=${data['botBalance']}, botData=$botData');
        debugPrint('refreshWalletSummary: RAW mainBalance=${data['mainBalance']}, mainData=$mainData');
        
        // Extract spot_assets from all-wallet-balance API (if available)
        final spotAssets = data['spot_assets'] as Map<String, dynamic>? ?? {};
        debugPrint('UnifiedWalletService: spot_assets raw data: ${data['spot_assets']}');
        debugPrint('UnifiedWalletService: spotAssets parsed count: ${spotAssets.length}');
        if (spotAssets.isNotEmpty) {
          debugPrint('UnifiedWalletService: Found ${spotAssets.length} spot assets: ${spotAssets.keys.toList()}');
          // Also populate _coinBalances from spot_assets so all tokens show
          _updateCoinBalancesFromAssets(spotAssets);
        }
        
        // Directly construct WalletBalance to avoid copyWith null coalescing issues
        final normalizedMain = mainData != null ? _normalizeBalance(mainData) : _walletBalance?.mainBalance;
        final finalSpotAssets = spotAssets.isNotEmpty ? spotAssets : _walletBalance?.spotAssets;
        
        _walletBalance = WalletBalance(
          mainBalance: normalizedMain,
          spotBalance: spotData,
          p2pBalance: p2pData,
          demoBalance: demoData,
          botBalance: botData,
          spotAssets: finalSpotAssets ?? const {},
        );
        
        debugPrint('refreshWalletSummary: mainBalance=${_walletBalance?.mainBalance}');
        debugPrint('refreshWalletSummary: mainUSDT=${mainUSDTBalance}, mainINR=${mainINRBalance}');
        debugPrint('refreshWalletSummary: spotBalance=${_walletBalance?.spotBalance}');
        debugPrint('refreshWalletSummary: p2pBalance=${_walletBalance?.p2pBalance}');
        debugPrint('refreshWalletSummary: botBalance=${_walletBalance?.botBalance}');
        debugPrint('refreshWalletSummary: demoBalance=${_walletBalance?.demoBalance}');
        
        _saveCachedData();
        if (emitToStream) {
          _walletBalanceController.add(_walletBalance);
        }
        _setError(null);

        debugPrint('UnifiedWalletService: Wallet summary refreshed (emitToStream: $emitToStream)');
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
      _isRefreshingSummary = false;
    }
  }

  // 2. Get spot coins balance
  static Future<Map<String, dynamic>> refreshSpotBalance({bool emitToStream = true}) async {
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
        
        _walletBalance = WalletBalance(
          mainBalance: _walletBalance?.mainBalance,
          spotBalance: usdtFree is num ? usdtFree.toDouble() : 0.0,
          p2pBalance: _walletBalance?.p2pBalance ?? 0.0,
          demoBalance: _walletBalance?.demoBalance ?? 0.0,
          botBalance: _walletBalance?.botBalance ?? 0.0,
          spotAssets: spotAssets.isNotEmpty ? spotAssets : (_walletBalance?.spotAssets ?? const {}),
        );
        
        _saveCachedData();
        if (emitToStream) {
          _walletBalanceController.add(_walletBalance);
          _coinBalanceController.add(List.unmodifiable(_coinBalance));
        }
        _setError(null);

        debugPrint('UnifiedWalletService: Spot balance refreshed: $usdtFree, spotAssets: ${spotAssets.length} (emitToStream: $emitToStream)');
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

  // 3. Get P2P wallet balance
  static Future<Map<String, dynamic>> refreshP2PBalance({bool emitToStream = true}) async {
    _setLoading(true);
    
    try {
      // Import P2P service locally to avoid circular imports
      final p2pService = await _getP2PBalance();
      
      if (p2pService != null && p2pService['success'] == true) {
        final data = p2pService['data'] ?? p2pService;
        debugPrint('UnifiedWalletService: P2P balance data: $data');
        
        // Extract USDT balance from P2P response
        double p2pUSDT = 0.0;
        if (data['balance'] != null) {
          p2pUSDT = double.tryParse(data['balance'].toString()) ?? 0.0;
        } else if (data['USDT'] != null) {
          p2pUSDT = _extractUSDTValue(data['USDT']);
        } else if (data['usdt'] != null) {
          p2pUSDT = _extractUSDTValue(data['usdt']);
        } else {
          // Try to extract from balances list
          p2pUSDT = _extractUSDTValue(data);
        }
        
        _walletBalance = WalletBalance(
          mainBalance: _walletBalance?.mainBalance,
          spotBalance: _walletBalance?.spotBalance ?? 0.0,
          p2pBalance: p2pUSDT,
          demoBalance: _walletBalance?.demoBalance ?? 0.0,
          botBalance: _walletBalance?.botBalance ?? 0.0,
          spotAssets: _walletBalance?.spotAssets ?? const {},
        );
        
        _saveCachedData();
        if (emitToStream) {
          _walletBalanceController.add(_walletBalance);
        }
        _setError(null);

        debugPrint('UnifiedWalletService: P2P balance refreshed: $p2pUSDT (emitToStream: $emitToStream)');
        return {'success': true, 'data': {'p2pBalance': p2pUSDT}};
      } else {
        debugPrint('UnifiedWalletService: Failed to fetch P2P balance: ${p2pService?['error'] ?? 'Unknown error'}');
        return {'success': false, 'error': 'Failed to fetch P2P balance'};
      }
    } catch (e) {
      debugPrint('UnifiedWalletService: Error fetching P2P balance: $e');
      return {'success': false, 'error': 'Network error: $e'};
    } finally {
      _setLoading(false);
    }
  }

  // Helper to get P2P balance
  static Future<Map<String, dynamic>?> _getP2PBalance() async {
    try {
      final token = await AuthService.getToken();
      final userId = await _getUserId();
      
      // Try multiple possible P2P endpoints
      final endpoints = [
        '$_baseUrl/p2p/v1/wallet/balance',
        '$_baseUrl/p2p/wallet/balance',
        '$_baseUrl/p2p/v1/balance',
        '$_baseUrl/p2p/balance',
      ];
      
      for (String endpoint in endpoints) {
        try {
          debugPrint('Trying P2P endpoint: $endpoint');
          
          final response = await http.get(
            Uri.parse(endpoint),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
              if (userId != null) 'X-User-Id': userId,
            },
          );
          
          debugPrint('P2P Balance API ($endpoint): ${response.statusCode}');
          
          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            debugPrint('P2P Balance success: $data');
            return data;
          } else if (response.statusCode == 401) {
            debugPrint('P2P Balance auth failed for endpoint: $endpoint');
            // Continue to next endpoint for 401
            continue;
          } else if (response.statusCode == 404) {
            debugPrint('P2P Balance endpoint not found: $endpoint');
            // Continue to next endpoint for 404
            continue;
          } else {
            debugPrint('P2P Balance error ${response.statusCode} for endpoint: $endpoint');
            // Try next endpoint
            continue;
          }
        } catch (e) {
          debugPrint('Error trying P2P endpoint $endpoint: $e');
          continue;
        }
      }
      
      debugPrint('All P2P endpoints failed');
      return null;
    } catch (e) {
      debugPrint('Error fetching P2P balance: $e');
      return null;
    }
  }

  // 4. Get bot wallet balance
  static Future<Map<String, dynamic>> refreshBotBalance({bool emitToStream = true}) async {
    _setLoading(true);
    
    try {
      final result = await _getBotWalletBalance();
      
      if (result['success'] == true) {
        final data = result['data'] ?? {};
        final balance = data['balance'] ?? data['availableBalance'] ?? data['totalBalance'] ?? 0.0;
        final inrBalance = data['inrBalance'] ?? 0.0;
        
        _walletBalance = WalletBalance(
          mainBalance: _walletBalance?.mainBalance,
          spotBalance: _walletBalance?.spotBalance ?? 0.0,
          p2pBalance: _walletBalance?.p2pBalance ?? 0.0,
          demoBalance: _walletBalance?.demoBalance ?? 0.0,
          botBalance: balance is num ? balance.toDouble() : 0.0,
          spotAssets: _walletBalance?.spotAssets ?? const {},
        );
        
        _botINRBalance = inrBalance is num ? inrBalance.toDouble() : 0.0;
        
        _saveCachedData();
        if (emitToStream) {
          _walletBalanceController.add(_walletBalance);
        }
        _setError(null);

        debugPrint('UnifiedWalletService: Bot balance refreshed: $balance, Bot INR: $_botINRBalance (emitToStream: $emitToStream)');
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

  // After subscription - refresh all wallet data
  static Future<void> refreshAfterSubscription() async {
    debugPrint('UnifiedWalletService: Refreshing after subscription...');
    await refreshWalletSummary();
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
      // Check if user is logged in first
      final isLoggedIn = await AuthService.isLoggedIn();
      if (!isLoggedIn) {
        debugPrint('Wallet Summary: User not logged in');
        return {'success': false, 'error': 'User not logged in'};
      }

      final headers = await _getHeaders();
      debugPrint('Wallet Summary: Headers = $headers');
      
      final response = await http.get(
        Uri.parse('$_baseUrl/wallet/v1/wallet/all-wallet-balance'),
        headers: headers,
      );

      debugPrint('Wallet Summary API: ${response.statusCode}');
      debugPrint('Wallet Summary Response: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return {'success': true, 'data': data['data'] ?? data};
        } else {
          return {'success': false, 'error': data['message'] ?? 'API returned false success'};
        }
      } else if (response.statusCode == 401) {
        debugPrint('Wallet Summary: Authentication failed - token may be expired');
        return {'success': false, 'error': 'Authentication failed - please login again'};
      } else if (response.statusCode == 404) {
        debugPrint('Wallet Summary: Endpoint not found');
        return {'success': false, 'error': 'Wallet endpoint not found'};
      } else {
        debugPrint('Wallet Summary: Server error ${response.statusCode}');
        return {'success': false, 'error': 'Server error: ${response.statusCode}'};
      }
    } catch (e) {
      debugPrint('Error fetching wallet summary: $e');
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> _getBotWalletBalance() async {
    try {
      // Check if user is logged in first
      final isLoggedIn = await AuthService.isLoggedIn();
      if (!isLoggedIn) {
        debugPrint('Bot Wallet: User not logged in');
        return {'success': false, 'error': 'User not logged in'};
      }

      final headers = await _getHeaders();
      debugPrint('Bot Wallet: Headers = $headers');
      
      // Validate token before making API call
      final token = headers['Authorization'];
      if (token == null || token.toString().isEmpty || token.toString() == 'Bearer null') {
        debugPrint('Bot Wallet: Invalid token - user needs to login properly');
        return {'success': false, 'error': 'Please login to view bot balance'};
      }
      
      // Use wallet summary API instead of bot balance endpoint (which doesn't exist on testing server)
      final response = await http.get(
        Uri.parse('http://65.0.196.122:8085/wallet/v1/wallet/all-wallet-balance'),
        headers: headers,
      );
      
      debugPrint('Bot Wallet API (using wallet summary): ${response.statusCode}');
      debugPrint('Bot Wallet Response: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Handle wallet summary response format
        if (data['success'] == true) {
          // Extract bot balance from wallet summary response
          double usdtBalance = 0.0;
          double inrBalance = 0.0;
          
          // Get bot balance from the response
          if (data['botBalance'] != null) {
            usdtBalance = data['botBalance'] is num ? data['botBalance'].toDouble() : 0.0;
            debugPrint('Bot Wallet: Found botBalance in wallet summary: $usdtBalance');
          }
          
          // Get INR balance if available
          if (data['botINR'] != null) {
            inrBalance = data['botINR'] is num ? data['botINR'].toDouble() : 0.0;
          } else if (data['mainBalance'] != null && data['mainBalance']['INR'] != null) {
            inrBalance = data['mainBalance']['INR'] is num ? data['mainBalance']['INR'].toDouble() : 0.0;
          }
          
          return {
            'success': true,
            'data': {
              'balance': usdtBalance,
              'availableBalance': usdtBalance,
              'totalBalance': usdtBalance,
              'inrBalance': inrBalance,
            }
          };
        }
        return {'success': false, 'error': data['message'] ?? 'Failed to fetch bot balance'};
      } else if (response.statusCode == 401) {
        debugPrint('Bot Wallet: Authentication failed - token may be expired');
        return {'success': false, 'error': 'Authentication failed - please login again'};
      } else {
        debugPrint('Bot Wallet: Server error ${response.statusCode}');
        return {'success': false, 'error': 'Server error: ${response.statusCode}'};
      }
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
    if (data == null) return 0.0;
    if (data is num) return data.toDouble();
    if (data is String) return double.tryParse(data) ?? 0.0;
    
    if (data is Map) {
      // 1. Check direct keys for INR (flat map)
      final inrKeys = ['INR', 'inr', 'Inr', 'inr_balance', 'inrBalance', 'inr_available', 'inrAvailable', 'INR_Holding', 'inrHolding'];
      for (var key in inrKeys) {
        if (data[key] != null) {
          final val = _parseBalanceField(data[key], preferTotal: true);
          debugPrint('UnifiedWalletService: Extracted INR via key "$key": $val');
          return val;
        }
      }

      // 2. Check for INR in balances list
      final balances = data['balances'];
      if (balances is List) {
        for (var b in balances) {
          if (b is Map && (b['coin']?.toString().toUpperCase() == 'INR' || b['asset']?.toString().toUpperCase() == 'INR')) {
            final val = _parseBalanceField(b, preferTotal: true);
            debugPrint('UnifiedWalletService: Extracted INR from balances list: $val');
            return val;
          }
        }
      }
      
      // 3. Check for INR in balances map
      if (balances is Map) {
        final inr = balances['INR'] ?? balances['inr'] ?? balances['Inr'];
        if (inr != null) {
          final val = _parseBalanceField(inr, preferTotal: true);
          debugPrint('UnifiedWalletService: Extracted INR from balances map: $val');
          return val;
        }
      }

      // 4. Fallback: check for 'balance' field if 'coin' is 'INR'
      final coinName = (data['coin'] ?? data['asset'])?.toString().toUpperCase();
      if (coinName == 'INR') {
        final val = _parseBalanceField(data, preferTotal: true);
        debugPrint('UnifiedWalletService: Extracted INR from direct coin map: $val');
        return val;
      }

      // 5. Recursive Deep Scan
      final recursiveVal = _findINRRecursively(data);
      if (recursiveVal > 0) {
        debugPrint('UnifiedWalletService: Extracted INR via recursive scan: $recursiveVal');
        return recursiveVal;
      }
    }
    return 0.0;
  }

  static double _findINRRecursively(dynamic data) {
    if (data == null) return 0.0;
    
    if (data is Map) {
      // 1. Direct Case-Insensitive Key Search
      final keys = data.keys.map((k) => k.toString().toUpperCase()).toList();
      final inrKeys = ['INR', 'INR_BALANCE', 'INRBALANCE', 'INR_AVAILABLE', 'INRAVAILABLE', 'INR_HOLDING', 'INRHOLDING'];
      
      for (var targetKey in inrKeys) {
        // Find actual key that matches targetKey (case-insensitive)
        String? actualKey;
        try {
          actualKey = data.keys.firstWhere(
            (k) => k.toString().toUpperCase() == targetKey,
          );
        } catch (e) {
          actualKey = null;
        }

        if (actualKey != null) {
          final val = _parseBalanceField(data[actualKey], preferTotal: true);
          if (val > 0) return val;
        }
      }

      // 2. Search for "coin": "INR" patterns
      String? coinKey;
      String? assetKey;
      String? currencyKey;
      try {
        coinKey = data.keys.firstWhere((k) => k.toString().toUpperCase() == 'COIN');
      } catch (e) { coinKey = null; }
      try {
        assetKey = data.keys.firstWhere((k) => k.toString().toUpperCase() == 'ASSET');
      } catch (e) { assetKey = null; }
      try {
        currencyKey = data.keys.firstWhere((k) => k.toString().toUpperCase() == 'CURRENCY');
      } catch (e) { currencyKey = null; }
      
      final coinVal = (data[coinKey] ?? data[assetKey] ?? data[currencyKey])?.toString().toUpperCase();
      if (coinVal == 'INR') {
        final val = _parseBalanceField(data, preferTotal: true);
        if (val > 0) return val;
      }
      
      // 3. Search nested maps (limited depth to avoid loops)
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

  static double _extractINRAvailableValue(dynamic data) {
    if (data == null) return 0.0;
    if (data is num) return data.toDouble();
    if (data is String) return double.tryParse(data) ?? 0.0;
    
    if (data is Map) {
      // 1. Check direct keys for INR (flat map)
      final directInr = data['INR'] ?? data['inr'] ?? data['Inr'] ?? data['inr_available'] ?? data['inrAvailable'] ?? data['inr_balance'] ?? data['inrBalance'];
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

      // 4. Fallback: check for 'available' field if 'coin' is 'INR'
      if (data['coin']?.toString().toUpperCase() == 'INR' || data['asset']?.toString().toUpperCase() == 'INR') {
        return _parseBalanceField(data, preferTotal: false);
      }
    }
    return 0.0;
  }

  static double _parseBalanceField(dynamic val, {bool preferTotal = true}) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    if (val is String) {
      // Remove commas and parse
      final cleaned = val.replaceAll(',', '');
      return double.tryParse(cleaned) ?? 0.0;
    }
    if (val is Map) {
      if (preferTotal) {
        final total = val['total'] ?? val['balance'] ?? val['amount'] ?? val['totalBalance'] ?? val['available'] ?? val['free'] ?? val['availableBalance'] ?? 0.0;
        return double.tryParse(total.toString()) ?? 0.0;
      } else {
        final available = val['available'] ?? val['free'] ?? val['availableBalance'] ?? val['total'] ?? val['balance'] ?? val['amount'] ?? val['totalBalance'] ?? 0.0;
        return double.tryParse(available.toString()) ?? 0.0;
      }
    }
    return 0.0;
  }

  static Map<String, dynamic> _normalizeBalance(dynamic data) {
    if (data == null) return {};
    
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    
    if (data is List) {
      // Convert list of coin objects to a map keyed by coin symbol
      final Map<String, dynamic> normalized = {};
      for (var item in data) {
        if (item is Map) {
          final coin = (item['coin'] ?? item['asset'] ?? item['assetCode'] ?? item['currency'])?.toString().toUpperCase();
          if (coin != null) {
            normalized[coin] = item;
          }
        }
      }
      debugPrint('UnifiedWalletService: Normalized list of ${data.length} items into map of ${normalized.length} coins');
      return normalized;
    }
    
    return {};
  }

  static void _updateCoinBalancesFromAssets(dynamic assets) {
    if (assets == null) return;
    
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
            free: double.tryParse(assetData['free']?.toString() ?? assetData['available']?.toString() ?? assetData['balance'] ?? '0') ?? 0.0,
            locked: double.tryParse(assetData['locked']?.toString() ?? '0') ?? 0.0,
          );
        }
        return CoinBalance(asset: assetName);
      }).where((c) => c.asset.isNotEmpty).toList();
    }
    
    // Check if INR is present in coin balances and update bot/total state if needed
    final inr = getCoinBalance('INR');
    if (inr != null) {
      debugPrint('UnifiedWalletService: Found INR in spot assets: ${inr.total}');
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

  static void refreshWalletBalance() {}
}

class ApiConfig {
  static String? get baseUrl => null;
}
