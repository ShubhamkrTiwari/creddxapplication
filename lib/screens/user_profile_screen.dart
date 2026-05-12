import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:upgrader/upgrader.dart';
import '../services/socket_service.dart';
import '../services/spot_service.dart';
import '../services/wallet_service.dart';
import '../services/unified_wallet_service.dart' as unified;
import 'invite_friends_screen.dart';
import 'login_screen.dart';
import 'update_profile_screen.dart';
import 'referral_hub_screen.dart';
import 'updates_screen.dart';
import 'feedback_screen.dart';
import 'kyc_digilocker_instruction_screen.dart';
import 'kyc_selfie_screen.dart';
import 'withdraw_screen.dart';
import 'deposit_screen.dart';
import 'inr_deposit_screen.dart';
import 'inr_withdraw_upi_screen.dart';
import 'partner_program_screen.dart'; // Affiliate Program
import '../services/user_service.dart';
import '../services/p2p_service.dart';
import '../services/auth_service.dart';
import '../widgets/bitcoin_loading_indicator.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  bool _isAssetsAllocationExpanded = false;
  String _selectedView = 'wallet'; // 'wallet' | 'coin' | 'spot'
  bool _isWalletHidden = true;
  final UserService _userService = UserService();
  List<dynamic> _trustedDevices = [];
  bool _isLoadingDevices = true;
  
  // WebSocket subscription for wallet balance
  StreamSubscription<Map<String, dynamic>>? _balanceSubscription;
  StreamSubscription<dynamic>? _unifiedWalletSubscription;
  Map<String, dynamic> _walletBalances = {};
  bool _isLoadingWallet = true;
  bool _isLoading = false;
  Timer? _kycStatusUpdateTimer;
  
  // Referral code state
  String? _referralCode;
  bool _isLoadingReferralCode = false;
  bool _isUpdateAvailable = false;
  String _currentVersion = "";

  // Wallet balance data from getWalletBalance API
  Map<String, dynamic> _apiWalletBalances = {};
  double _mainUSDT = 0.0;
  double _spotUSDT = 0.0;
  double _p2pUSDT = 0.0;
  double _botUSDT = 0.0;
  double _holdingUSDT = 0.0;
  
  // Asset prices - will be updated dynamically
  Map<String, double> _assetPrices = {'ETH': 2450.00, 'USDT': 1.00, 'USDC': 1.00, 'BTC': 45000.00};
  Map<String, dynamic> _allWalletData = {};
  List<String> _allSystemCoins = [];
  bool _isLoadingAssetPrices = true;
  
  // Conversion rates
  double _inrToUsdtRate = 52.0; // Dynamic conversion rate from API
  double _usdtToInrRate = 1.0 / 52.0; // Reverse conversion rate
  static const String _inrToUsdtApiUrl = 'http://65.0.196.122:8085/api/wallet/v1/inr/convert/inr-to-usdt';
  static const String _usdtToInrApiUrl = 'http://65.0.196.122:8085/api/wallet/v1/inr/convert/usdt-to-inr';
  
  static const String _wsBaseUrl = 'wss://api4.creddx.com/ws';
  static const String _httpBaseUrl = 'http://65.0.196.122:8085';

  @override
  void initState() {
    super.initState();
    
    // Load user data and check KYC status immediately when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserData();
      // App update check removed
    });
    
    _loadTrustedDevices();
    _subscribeToBalance();
    _loadAllWalletData();
    _loadAssetPrices();
    _loadConversionRate();
    _fetchWalletBalances();
    _checkVersionUpdate();
    
    // Initialize UnifiedWalletService and refresh balances to get INR
    _initUnifiedWallet();
    
    // Add timeout to prevent infinite loading
    Timer(const Duration(seconds: 10), () {
      if (mounted && _isLoadingWallet) {
        setState(() {
          _isLoadingWallet = false;
        });
        debugPrint('Loading timeout reached - forcing loading state to false');
      }
    });
    
    // Refresh portfolio calculation periodically to ensure updated conversion rates
    Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        setState(() {}); // Trigger rebuild to update portfolio with current rates
      }
    });
    
    // Periodic update checks removed
    
    // Refresh conversion rate every 5 minutes
    Timer.periodic(const Duration(minutes: 5), (timer) {
      if (mounted) {
        _loadConversionRate();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Force refresh user data when screen regains focus (includes KYC status checking)
    // This ensures status is always up-to-date from /auth/me
    debugPrint('Profile screen: didChangeDependencies - forcing KYC status refresh');
    _userService.fetchProfileDataFromAPI().then((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }
  
  
  // Fetch wallet balances from getWalletBalance API
  Future<void> _fetchWalletBalances() async {
    try {
      debugPrint('========== FETCHING WALLET BALANCES ==========');
      final result = await WalletService.getWalletBalance();
      debugPrint('API Result: $result');

      if (result['success'] == true && result['data'] != null) {
        final data = result['data'];
        debugPrint('API Data keys: ${data.keys}');
        debugPrint('Main data: ${data['main']}');
        debugPrint('Spot data: ${data['spot']}');
        debugPrint('P2P data: ${data['p2p']}');
        debugPrint('Bot data: ${data['bot'] ?? data['demo_bot']}');
        debugPrint('Holding data: ${data['holding']}');

        setState(() {
          _apiWalletBalances = data;
          // Extract USDT balances from each wallet type
          _mainUSDT = _extractUSDTFromWalletData(data['main']);
          _spotUSDT = _extractUSDTFromWalletData(data['spot']);
          _p2pUSDT = _extractUSDTFromWalletData(data['p2p']);
          _botUSDT = _extractUSDTFromWalletData(data['bot'] ?? data['demo_bot']);
          _holdingUSDT = _extractUSDTFromWalletData(data['holding']);
          _isLoadingWallet = false;

          debugPrint('========== EXTRACTED BALANCES ==========');
          debugPrint('Main: $_mainUSDT');
          debugPrint('Spot: $_spotUSDT');
          debugPrint('P2P: $_p2pUSDT');
          debugPrint('Bot: $_botUSDT');
          debugPrint('Holding: $_holdingUSDT');
        });

        // Aggressive grand total fetch as fallback
        final grandTotal = await WalletService.getTotalUSDTBalance();
        if (mounted && grandTotal > 0 && (_mainUSDT + _spotUSDT + _p2pUSDT + _botUSDT + _holdingUSDT) == 0) {
          setState(() {
            _mainUSDT = grandTotal; // Assign to main as fallback so it shows in total
          });
          debugPrint('Aggressive grand total fallback applied: $grandTotal');
        }
      } else {
        debugPrint('API call failed or no data: $result');
        setState(() {
          _isLoadingWallet = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('Error fetching wallet balances: $e');
      debugPrint('Stack trace: $stackTrace');
      setState(() {
        _isLoadingWallet = false;
      });
    }
  }

  // Helper to extract USDT balance from wallet data
  double _extractUSDTFromWalletData(dynamic walletData) {
    if (walletData == null) return 0.0;

    // 1. If it's a number, return it
    if (walletData is num) return walletData.toDouble();
    if (walletData is String) return double.tryParse(walletData) ?? 0.0;

    if (walletData is Map) {
      // 2. Check for USDT key (Map or Num)
      final usdt = walletData['USDT'] ?? walletData['usdt'];
      if (usdt != null) {
        if (usdt is num) return usdt.toDouble();
        if (usdt is String) return double.tryParse(usdt) ?? 0.0;
        if (usdt is Map) {
          final val = usdt['total'] ?? usdt['balance'] ?? usdt['available'] ?? usdt['free'] ?? usdt['amount'] ?? '0';
          return double.tryParse(val.toString()) ?? 0.0;
        }
      }

      // 3. Handle balances list format
      if (walletData['balances'] is List) {
        final balances = walletData['balances'] as List;
        for (var b in balances) {
          if (b is Map && (b['coin']?.toString().toUpperCase() == 'USDT' || b['asset']?.toString().toUpperCase() == 'USDT')) {
            final val = b['total'] ?? b['balance'] ?? b['available'] ?? b['free'] ?? b['amount'] ?? '0';
            return double.tryParse(val.toString()) ?? 0.0;
          }
        }
      }

      // 4. Handle balances map format
      if (walletData['balances'] is Map) {
        final balances = walletData['balances'] as Map;
        final usdtData = balances['USDT'] ?? balances['usdt'];
        if (usdtData != null) {
          if (usdtData is num) return usdtData.toDouble();
          if (usdtData is Map) {
            final val = usdtData['total'] ?? usdtData['balance'] ?? usdtData['available'] ?? usdtData['free'] ?? usdtData['amount'] ?? '0';
            return double.tryParse(val.toString()) ?? 0.0;
          }
        }
      }

      // 5. Direct common fields (if the Map itself represents the USDT balance)
      final val = walletData['total'] ?? walletData['balance'] ?? walletData['available'] ?? walletData['free'] ?? walletData['amount'];
      if (val != null) {
        return double.tryParse(val.toString()) ?? 0.0;
      }
    }

    return 0.0;
  }

  // Initialize UnifiedWalletService and refresh wallet summary
  Future<void> _initUnifiedWallet() async {
    try {
      // Initialize the unified wallet service
      await unified.UnifiedWalletService.initialize();
      
      // Refresh wallet summary to get INR balance
      final result = await unified.UnifiedWalletService.refreshWalletSummary();
      debugPrint('_initUnifiedWallet: refreshWalletSummary result: $result');
      
      // Also refresh bot balance which may have INR
      await unified.UnifiedWalletService.refreshBotBalance();
      
      // Get current INR balance and update UI
      final inrBalance = unified.UnifiedWalletService.mainINRBalance;
      debugPrint('_initUnifiedWallet: Current INR balance: $inrBalance');
      
      if (mounted && inrBalance > 0) {
        setState(() {
          _walletBalances['inr'] = inrBalance;
          _walletBalances['INR'] = inrBalance;
          _isLoadingWallet = false;
        });
      }
    } catch (e) {
      debugPrint('_initUnifiedWallet error: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingWallet = false);
      }
    }
  }

  void _subscribeToBalance() {
    // Subscribe to UnifiedWalletService for all balance updates
    _unifiedWalletSubscription = unified.UnifiedWalletService.walletBalanceStream.listen((walletBalance) {
      if (mounted) {
        setState(() {
          _isLoadingWallet = walletBalance == null;
          // Trigger rebuild to refresh _getCoinBalance results
        });
      }
    });

    _balanceSubscription = SocketService.balanceStream.listen((data) {
      final eventType = data['type'];
      debugPrint('UserProfileScreen: Socket event received: type=$eventType');
      debugPrint('Raw data: $data');

      // Handle both balance_update and wallet_summary events
      if (eventType == 'balance_update' || eventType == 'wallet_summary') {
        // Extract payload from wrapped data
        final payload = data['data'] ?? data;

        // Handle wallet_summary format (has mainBalance, p2pBalance etc)
        if (eventType == 'wallet_summary' && payload is Map) {
          // Extract INR from mainBalance
          final mainBalance = payload['mainBalance'] ?? payload['main'];
          if (mainBalance is Map) {
            final inrVal = mainBalance['INR'] ?? mainBalance['inr'] ?? mainBalance['Inr'];
            if (inrVal != null) {
              final inrAmount = double.tryParse(inrVal.toString()) ?? 0.0;
              debugPrint('UserProfileScreen: INR from wallet_summary mainBalance: $inrAmount');
              if (mounted) {
                setState(() {
                  _walletBalances['inr'] = inrAmount;
                  _walletBalances['INR'] = inrAmount;
                  _walletBalances['mainBalance'] = mainBalance;
                  _isLoadingWallet = false;
                });
              }
            }
          }

          // Also check for INR at top level
          final topInr = payload['INR'] ?? payload['inr'] ?? payload['inr_available'] ?? payload['inrBalance'];
          if (topInr != null) {
            final inrAmount = double.tryParse(topInr.toString()) ?? 0.0;
            debugPrint('UserProfileScreen: INR from wallet_summary top level: $inrAmount');
            if (mounted && inrAmount > 0) {
              setState(() {
                _walletBalances['inr'] = inrAmount;
                _walletBalances['INR'] = inrAmount;
                _isLoadingWallet = false;
              });
            }
          }
        }

        // Handle assets array format (from balance_update)
        if (payload['assets'] != null) {
          final assets = payload['assets'] as List<dynamic>?;
          if (assets != null && assets.isNotEmpty) {
            // Map 'asset' to 'coin' to match UserProfileScreen expectations
            final mappedAssets = assets.map((a) => {
              'coin': a['asset'],
              'available': a['available'],
              'locked': a['locked'],
            }).toList();

            if (mounted) {
              setState(() {
                _walletBalances['spot'] = {'balances': mappedAssets};
                _walletBalances['spotBalance'] = mappedAssets;

                // Also update top-level for 'Coin View'
                for (var asset in assets) {
                  final symbol = asset['asset']?.toString().toLowerCase();
                  if (symbol != null) {
                    _walletBalances[symbol] = asset['available'];
                    _walletBalances['${symbol}_available'] = asset['available'];
                    _walletBalances['${symbol}_total'] = (double.tryParse(asset['available']?.toString() ?? '0') ?? 0.0) +
                                                         (double.tryParse(asset['locked']?.toString() ?? '0') ?? 0.0);
                  }
                }

                _isLoadingWallet = false;
              });
            }
          }
        }

        // Handle single INR balance update format
        if (payload['asset']?.toString().toUpperCase() == 'INR' ||
            payload['inr_available'] != null ||
            payload['inr'] != null) {
          final inrAvailable = double.tryParse(
            payload['inr_available']?.toString() ??
            payload['available']?.toString() ??
            payload['inr']?.toString() ?? '0'
          ) ?? 0.0;

          final inrLocked = double.tryParse(
            payload['locked']?.toString() ?? '0'
          ) ?? 0.0;

          debugPrint('UserProfileScreen: INR balance from socket: available=$inrAvailable, locked=$inrLocked');

          if (mounted) {
            setState(() {
              _walletBalances['inr'] = inrAvailable;
              _walletBalances['inr_available'] = inrAvailable;
              _walletBalances['inr_total'] = inrAvailable + inrLocked;
              _walletBalances['INR'] = inrAvailable;
              _isLoadingWallet = false;
            });
          }
        }
      }
    });
  }
  
  // Load INR to USDT conversion rate from API
  Future<void> _loadConversionRate() async {
    try {
      debugPrint('=== Loading conversion rates ===');
      
      final token = await AuthService.getToken();
      
      // Fetch INR to USDT rate
      final inrResponse = await http.get(
        Uri.parse(_inrToUsdtApiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));
      
      debugPrint('INR to USDT API Response Status: ${inrResponse.statusCode}');
      debugPrint('INR to USDT API Response Body: ${inrResponse.body}');
      
      // Fetch USDT to INR rate
      final usdtResponse = await http.get(
        Uri.parse(_usdtToInrApiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));
      
      debugPrint('USDT to INR API Response Status: ${usdtResponse.statusCode}');
      debugPrint('USDT to INR API Response Body: ${usdtResponse.body}');
      
      double newInrToUsdtRate = 52.0; // fallback rate
      double newUsdtToInrRate = 1.0 / 52.0; // fallback rate
      
      // Parse INR to USDT response
      if (inrResponse.statusCode == 200) {
        final data = json.decode(inrResponse.body);
        debugPrint('Parsed INR to USDT data: $data');
        
        if (data['success'] == true && data['data'] != null) {
          final rateData = data['data'];
          if (rateData['rate'] != null) {
            newInrToUsdtRate = double.tryParse(rateData['rate'].toString()) ?? 52.0;
          } else if (rateData['conversion_rate'] != null) {
            newInrToUsdtRate = double.tryParse(rateData['conversion_rate'].toString()) ?? 52.0;
          } else if (rateData['inr_to_usdt'] != null) {
            newInrToUsdtRate = double.tryParse(rateData['inr_to_usdt'].toString()) ?? 52.0;
          }
        } else if (data['rate'] != null) {
          newInrToUsdtRate = double.tryParse(data['rate'].toString()) ?? 52.0;
        } else if (data['conversion_rate'] != null) {
          newInrToUsdtRate = double.tryParse(data['conversion_rate'].toString()) ?? 52.0;
        } else if (data['inr_to_usdt'] != null) {
          newInrToUsdtRate = double.tryParse(data['inr_to_usdt'].toString()) ?? 52.0;
        }
      }
      
      // Parse USDT to INR response
      if (usdtResponse.statusCode == 200) {
        final data = json.decode(usdtResponse.body);
        debugPrint('Parsed USDT to INR data: $data');
        
        if (data['success'] == true && data['data'] != null) {
          final rateData = data['data'];
          if (rateData['rate'] != null) {
            newUsdtToInrRate = double.tryParse(rateData['rate'].toString()) ?? (1.0 / 52.0);
          } else if (rateData['conversion_rate'] != null) {
            newUsdtToInrRate = double.tryParse(rateData['conversion_rate'].toString()) ?? (1.0 / 52.0);
          } else if (rateData['usdt_to_inr'] != null) {
            newUsdtToInrRate = double.tryParse(rateData['usdt_to_inr'].toString()) ?? (1.0 / 52.0);
          }
        } else if (data['rate'] != null) {
          newUsdtToInrRate = double.tryParse(data['rate'].toString()) ?? (1.0 / 52.0);
        } else if (data['conversion_rate'] != null) {
          newUsdtToInrRate = double.tryParse(data['conversion_rate'].toString()) ?? (1.0 / 52.0);
        } else if (data['usdt_to_inr'] != null) {
          newUsdtToInrRate = double.tryParse(data['usdt_to_inr'].toString()) ?? (1.0 / 52.0);
        }
      }
      
      if (mounted) {
        setState(() {
          _inrToUsdtRate = newInrToUsdtRate;
          _usdtToInrRate = newUsdtToInrRate;
        });
      }
      debugPrint('Updated conversion rates:');
      debugPrint('INR to USDT: $_inrToUsdtRate');
      debugPrint('USDT to INR: $_usdtToInrRate');
    } catch (e) {
      debugPrint('Error loading conversion rates: $e');
      debugPrint('Using fallback conversion rates');
    }
  }
  
  String _getAssetBalance(String asset) {
    if (_isLoadingWallet) return '...';
    
    final balance = _walletBalances[asset.toLowerCase()] ?? 
                   _walletBalances[asset] ?? 
                   _walletBalances['${asset.toLowerCase()}_available'] ??
                   _walletBalances['${asset}_available'];
    
    if (balance != null) {
      final amount = double.tryParse(balance.toString()) ?? 0.0;
      if (amount > 0) return '$amount $asset';
    }
    
    // Check nested data structure
    final nestedData = _walletBalances['data'];
    if (nestedData is Map) {
      final nestedBalance = nestedData[asset.toLowerCase()] ?? nestedData[asset];
      if (nestedBalance != null) {
        final amount = double.tryParse(nestedBalance.toString()) ?? 0.0;
        if (amount > 0) return '$amount $asset';
      }
    }
    
    return '0.00 $asset';
  }
  
  String _getAssetPrice(String asset) {
    final price = _assetPrices[asset] ?? 0.0;
    return '\$${price.toStringAsFixed(2)}';
  }
  
  double _getAssetValue(String asset) {
    final balanceStr = _getAssetBalance(asset).replaceAll(' $asset', '').replaceAll(asset, '').trim();
    final balance = double.tryParse(balanceStr) ?? 0.0;
    final price = _assetPrices[asset] ?? 0.0;
    return balance * price;
  }
  
  // Get all coins that have a non-zero balance across all wallets
  List<String> _getAllCoinsWithBalances() {
    final Set<String> coinSet = {'INR', 'USDT'}; // Always include these
    
    // Add all coins from system API if available
    if (_allSystemCoins.isNotEmpty) {
      coinSet.addAll(_allSystemCoins);
    }
    
    // Check all possible sources in _walletBalances
    final data = _walletBalances;
    
    // Helper to check nested wallet structure
    void checkWallet(dynamic wallet) {
      if (wallet is Map) {
        final balances = wallet['balances'];
        if (balances is List) {
          for (var b in balances) {
            if (b is Map) {
              final coin = b['coin']?.toString().toUpperCase() ?? b['asset']?.toString().toUpperCase();
              final amount = double.tryParse(b['total']?.toString() ?? b['available']?.toString() ?? '0') ?? 0.0;
              if (coin != null && amount > 0) coinSet.add(coin);
            }
          }
        }
      }
    }
    
    // Check categorized wallets
    checkWallet(data['main']);
    checkWallet(data['spot']);
    checkWallet(data['p2p']);
    checkWallet(data['bot']);
    
    // Check flat mapping from UserService or other sources
    data.forEach((key, value) {
      if (value is num && value > 0) {
        // Simple keys like 'btc': 0.5
        final coin = key.toUpperCase();
        if (coin.length <= 5) coinSet.add(coin);
      }
    });

    // Check spot_raw specifically
    final spotRaw = data['spot_raw'];
    if (spotRaw is List) {
      for (var asset in spotRaw) {
        if (asset is Map) {
          final coin = asset['asset']?.toString().toUpperCase() ?? asset['coin']?.toString().toUpperCase();
          final amount = double.tryParse(asset['available']?.toString() ?? asset['total']?.toString() ?? '0') ?? 0.0;
          if (coin != null && amount > 0) coinSet.add(coin);
        }
      }
    }

    final result = coinSet.toList();
    // Sort: INR first, then USDT, then others alphabetical
    result.sort((a, b) {
      if (a == 'INR') return -1;
      if (b == 'INR') return 1;
      if (a == 'USDT') return -1;
      if (b == 'USDT') return 1;
      return a.compareTo(b);
    });
    
    return result;
  }

  // Get all unique coins from wallet data dynamically
  List<String> _getAllCoinsFromWalletData() {
    final Set<String> coins = {};
    final data = _walletBalances;
    
    if (data.isEmpty) return ['INR', 'USDT', 'BTC', 'ETH'];
    
    // Check direct coin keys
    final directCoinKeys = ['inr', 'usdt', 'btc', 'eth', 'usdc', 'bnb', 'ada', 'sol', 'dot', 'xrp', 'matic', 'avax'];
    for (final key in directCoinKeys) {
      if (data[key] != null || data['${key}_available'] != null || data['${key}_total'] != null) {
        coins.add(key.toUpperCase());
      }
    }
    
    // Check nested data structure
    final nestedData = data['data'];
    if (nestedData is Map) {
      // Check for direct coin keys in nested data
      for (final key in directCoinKeys) {
        if (nestedData[key] != null || nestedData['${key}_available'] != null || nestedData['${key}_total'] != null) {
          coins.add(key.toUpperCase());
        }
      }
      
      // Check wallet structures (main, spot, p2p, bot)
      final walletTypes = ['main', 'spot', 'p2p', 'bot'];
      for (final walletType in walletTypes) {
        final wallet = nestedData[walletType];
        if (wallet is Map) {
          final balances = wallet['balances'];
          if (balances is List) {
            for (final bal in balances) {
              if (bal is Map) {
                final coin = bal['coin']?.toString().toUpperCase() ?? bal['asset']?.toString().toUpperCase();
                if (coin != null && coin.isNotEmpty) {
                  coins.add(coin);
                }
              }
            }
          }
          // Check for coin totals in wallet
          for (final key in wallet.keys) {
            if (key.endsWith('_total') || key.endsWith('_available')) {
              final coin = key.replaceAll('_total', '').replaceAll('_available', '').toUpperCase();
              if (coin.isNotEmpty) coins.add(coin);
            }
          }
        }
      }
    }
    
    // Check top-level wallet structures
    final walletTypes = ['main', 'spot', 'p2p', 'bot'];
    for (final walletType in walletTypes) {
      final wallet = data[walletType];
      if (wallet is Map) {
        final balances = wallet['balances'];
        if (balances is List) {
          for (final bal in balances) {
            if (bal is Map) {
              final coin = bal['coin']?.toString().toUpperCase() ?? bal['asset']?.toString().toUpperCase();
              if (coin != null && coin.isNotEmpty) {
                coins.add(coin);
              }
            }
          }
        }
      }
    }
    
    // Ensure INR is always included if present
    if (data['inr'] != null || data['inr_available'] != null || data['inr_total'] != null) {
      coins.add('INR');
    }
    
    final result = coins.toList()..sort();
    return result.isEmpty ? ['INR', 'USDT', 'BTC', 'ETH'] : result;
  }

  // Helper method to parse balance values with proper error handling
  double _parseBalanceValue(String balanceStr, String currency) {
    try {
      // Remove currency symbols, asterisks, and whitespace
      String cleanStr = balanceStr
          .replaceAll(currency, '')
          .replaceAll('***', '')
          .replaceAll('...', '')
          .trim();
      
      // Handle empty string or loading state
      if (cleanStr.isEmpty || cleanStr == '...') {
        return 0.0;
      }
      
      // Parse the cleaned string to double
      final value = double.tryParse(cleanStr);
      return value ?? 0.0;
    } catch (e) {
      debugPrint('Error parsing balance value: $balanceStr, error: $e');
      return 0.0;
    }
  }

  // Refresh asset allocation data
  Future<void> _refreshAssetData() async {
    setState(() {
      _isLoadingWallet = true;
      _isLoadingAssetPrices = true;
    });
    
    await Future.wait([
      _loadAllWalletData(),
      _loadAssetPrices(),
    ]);
  }

  // Dedicated method to refresh spot holdings from API
  Future<void> _refreshSpotData() async {
    debugPrint('_refreshSpotData: Refreshing spot data from API...');
    setState(() {
      _isLoadingWallet = true;
    });

    try {
      // Fetch fresh spot balance from SpotService
      final spotResult = await SpotService.getBalance(forceRefresh: true);
      debugPrint('_refreshSpotData: SpotService result: $spotResult');

      if (spotResult['success'] == true && spotResult['data'] != null) {
        final data = spotResult['data'];
        if (data is Map) {
          setState(() {
            // Update spot_raw with fresh data (including all coins)
            final rawAssets = data['raw_assets'] as List?;
            if (rawAssets != null) {
              _allWalletData['spot_raw'] = rawAssets.where((a) {
                final assetName = (a['asset']?.toString().toUpperCase() ?? a['coin']?.toString().toUpperCase());
                return assetName?.isNotEmpty ?? false;
              }).toList();
            }
            
            // Also update assets map
            final assetsMap = data['assets'] as Map?;
            if (assetsMap != null) {
              _allWalletData['assets'] = assetsMap;
            }
            
            _walletBalances = _allWalletData;
            _isLoadingWallet = false;
          });
          debugPrint('_refreshSpotData: Updated spot data successfully');
        }
      } else {
        debugPrint('_refreshSpotData: Failed to fetch spot data: ${spotResult['error']}');
        setState(() {
          _isLoadingWallet = false;
        });
      }
    } catch (e) {
      debugPrint('_refreshSpotData: Error refreshing spot data: $e');
      setState(() {
        _isLoadingWallet = false;
      });
    }
  }

  // Load comprehensive wallet data from API
  // NOTE: INR balance is NOT fetched from API - only from sockets via _subscribeToBalance()
  Future<void> _loadAllWalletData() async {
    if (!mounted) return;
    setState(() {
      _isLoadingWallet = true;
    });

    try {
      Map<String, dynamic> aggregatedData = {};
      
      // Preserve existing INR from socket before overwriting
      final existingInr = _walletBalances['inr'] ?? _walletBalances['INR'] ??
                          _walletBalances['inr_available'] ?? _walletBalances['INR_available'];
      
      // 1. Try user service - fetches user assets from /user/v1/user
      final userResult = await UserService.getUserAssets();
      if (userResult['success'] == true && userResult['data'] != null) {
        final data = userResult['data'];
        if (data is Map) {
          // Filter out INR fields - INR only from sockets
          final filteredData = Map<String, dynamic>.from(data);
          filteredData.removeWhere((key, value) => 
            key.toLowerCase().contains('inr') || 
            (key.toLowerCase() == 'asset' && value?.toString().toUpperCase() == 'INR')
          );
          aggregatedData.addAll(filteredData);
        }
        debugPrint('Loaded user assets from UserService (INR filtered): $data');
      }

      // 2. Fetch wallet balances from WalletService (Main, P2P, Bot) - excluding INR
      final walletResult = await WalletService.getAllWalletBalances();
      if (walletResult['success'] == true && walletResult['data'] != null) {
        final data = walletResult['data'];
        // Merge with existing data, excluding INR
        if (data is Map) {
          data.forEach((key, value) {
            // Skip INR-related fields
            if (!key.toLowerCase().contains('inr')) {
              aggregatedData[key] = value;
            }
          });
        }
        debugPrint('Loaded wallet data from WalletService (INR excluded): $data');
      }

      // 3. Fetch spot balance from SpotService - including all coins
      final spotResult = await SpotService.getBalance();
      if (spotResult['success'] == true && spotResult['data'] != null) {
        final data = spotResult['data'];
        if (data is Map) {
          // Store spot assets separately, including all coins
          // Support both Map and List formats for robustness
          final assetsData = data['assets'];
          if (assetsData is List) {
            aggregatedData['spot_assets'] = assetsData.where((a) => 
              (a['asset']?.toString().toUpperCase() ?? a['coin']?.toString().toUpperCase())?.isNotEmpty ?? false
            ).toList();
          } else if (assetsData is Map) {
            final List<Map<String, dynamic>> convertedList = [];
            assetsData.forEach((key, value) {
              if (value is Map) {
                convertedList.add({
                  'asset': key,
                  'available': value['available'],
                  'locked': value['locked'],
                  'free': value['free'],
                });
              }
            });
            aggregatedData['spot_assets'] = convertedList;
          }
          
          final rawAssets = data['raw_assets'] as List?;
          if (rawAssets != null) {
            aggregatedData['spot_raw'] = rawAssets.where((a) =>
              (a['asset']?.toString().toUpperCase() ?? a['coin']?.toString().toUpperCase())?.isNotEmpty ?? false
            ).toList();
          }
          
          // Also merge top level fields if not present, excluding INR
          data.forEach((key, value) {
            if (!aggregatedData.containsKey(key) && !key.toLowerCase().contains('inr')) {
              aggregatedData[key] = value;
            }
          });
        }
        debugPrint('Loaded spot wallet data from SpotService (INR excluded): $data');
      }

      // Restore INR from socket if it was preserved
      if (existingInr != null) {
        aggregatedData['inr'] = existingInr;
        aggregatedData['INR'] = existingInr;
      }

      // 4. Fetch all supported coins from system
      final allCoinsData = await WalletService.getAllCoins();
      final List<String> apiCoins = [];
      if (allCoinsData.isNotEmpty) {
        for (var coin in allCoinsData) {
          final symbol = (coin['coinSymbol'] ?? coin['symbol'] ?? '').toString().toUpperCase();
          if (symbol.isNotEmpty) apiCoins.add(symbol);
        }
      }

      setState(() {
        _allWalletData = aggregatedData;
        _walletBalances = aggregatedData;
        _allSystemCoins = apiCoins;
        _isLoadingWallet = false;
      });
    } catch (e) {
      debugPrint('Error loading wallet data in Profile: $e');
      setState(() {
        _isLoadingWallet = false;
      });
    }
  }
  
  // Load real-time asset prices
  Future<void> _loadAssetPrices() async {
    try {
      // This would typically come from a market data API
      // For now, using mock data with some realistic values
      setState(() {
        _assetPrices = {
          'BTC': 43500.00,
          'ETH': 2250.00,
          'USDT': 1.00,
          'USDC': 1.00,
          'BNB': 310.00,
          'ADA': 0.45,
          'SOL': 98.00,
          'DOT': 7.20,
        };
        _isLoadingAssetPrices = false;
      });
    } catch (e) {
      debugPrint('Error loading asset prices: $e');
      setState(() {
        _isLoadingAssetPrices = false;
      });
    }
  }

  Future<void> _checkVersionUpdate() async {
    try {
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        _currentVersion = packageInfo.version;
      });

      // We use the same Upgrader instance to check for updates
      final upgrader = Upgrader();
      await upgrader.initialize();
      
      if (upgrader.isUpdateAvailable()) {
        setState(() {
          _isUpdateAvailable = true;
        });
      }
    } catch (e) {
      debugPrint('Error checking version update: $e');
    }
  }

  Future<void> _loadUserData() async {
    // Load user data from /auth/me endpoint (includes KYC status)
    await _userService.initUserData();
    
    if (mounted) {
      setState(() {});
    }
    
    // Fetch referral code with UI update callback
    await _userService.fetchReferralCode(onReferralCodeLoaded: () {
      if (mounted) {
        setState(() {
          _referralCode = _userService.referralCode;
        });
      }
    });
    
    // Start real-time status checking after initial load
    _startRealTimeStatusCheck();
    
    // Refresh again after API data is fetched (IP address comes from login activity API)
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() {});
    }
  }

  // Refresh KYC status when user clicks refresh button
  Future<void> _refreshKYCStatus() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 16),
              Text('Refreshing KYC status...'),
            ],
          ),
          backgroundColor: const Color(0xFF84BD00),
          duration: Duration(seconds: 2),
        ),
      );

      // Store the current status before refresh
      String previousStatus = _userService.kycStatus;
      
      // Fetch fresh KYC status from /auth/me endpoint only
      await _userService.fetchProfileDataFromAPI();
      
      String currentStatus = _userService.kycStatus;
      print('✅ Refresh KYC - Previous: "$previousStatus", Current: "$currentStatus"');
      
      // If status hasn't changed and it's still the same, it might be due to rate limit
      // Check if we should show a rate limit message
      if (previousStatus == currentStatus && currentStatus == 'Pending') {
        // Try to check via KYC status endpoint to see if we get rate limit error
        final kycCheckResult = await _userService.checkKYCStatusPost();
        if (kycCheckResult['error'] != null && 
            (kycCheckResult['error'].toString().toLowerCase().contains('limit') ||
             kycCheckResult['error'].toString().toLowerCase().contains('429'))) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('API limit reached. Your KYC status will be updated automatically once processed.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
          return;
        }
      }
      
      // Show appropriate message based on status
      if (currentStatus == 'Completed') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('KYC status refreshed: Completed'),
            backgroundColor: Color(0xFF84BD00),
          ),
        );
      } else if (currentStatus == 'Rejected') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('KYC status refreshed: Rejected'),
            backgroundColor: Colors.red,
          ),
        );
      } else if (currentStatus == 'Pending') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('KYC status refreshed: Pending verification'),
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('KYC status refreshed: Not Started'),
            backgroundColor: Colors.grey,
          ),
        );
      }
    } catch (e) {
      print('Error refreshing KYC status: $e');
      // Check if error is related to rate limiting
      if (e.toString().toLowerCase().contains('limit') || 
          e.toString().toLowerCase().contains('429')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('API limit reached. Please try again later.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error refreshing KYC status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        // Update UI to reflect new status
        setState(() {});
      }
    }
  }

  Future<void> _loadTrustedDevices() async {
    try {
      debugPrint('Loading trusted devices...'); // Debug log
      final devices = await P2PService.getTrustedDevices();
      debugPrint('Fetched trusted devices: $devices'); // Debug log
      
      setState(() {
        _trustedDevices = devices;
        _isLoadingDevices = false;
      });
    } catch (e) {
      debugPrint('Error loading trusted devices: $e'); // Debug log
      setState(() {
        _trustedDevices = [];
        _isLoadingDevices = false;
      });
    }
  }

  // Show real-time status update notification
  void _showRealTimeStatusUpdate(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFF84BD00),
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
          ),
        ),
      );
    }
  }

  // Start real-time KYC status checking
  void _startRealTimeStatusCheck() {
    _stopRealTimeKYCUpdates(); // Clear any existing timer
    
    // Check KYC status every 10 seconds from /auth/me endpoint
    _kycStatusUpdateTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      try {
        await _userService.fetchProfileDataFromAPI();
        
        if (mounted) {
          setState(() {});
        }
      } catch (e) {
        print('Error in real-time status check: $e');
      }
    });
  }

  // Stop real-time KYC status checking
  void _stopRealTimeKYCUpdates() {
    _kycStatusUpdateTimer?.cancel();
    _kycStatusUpdateTimer = null;
  }

  @override
  void dispose() {
    _stopRealTimeKYCUpdates();
    _balanceSubscription?.cancel();
    _unifiedWalletSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: Colors.white),
        ),
        title: const Text('Profile', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Image.asset(
                            'assets/images/Hello!.gif',
                            width: 35,
                            height: 35,
                            errorBuilder: (context, error, stackTrace) => const Icon(
                              Icons.waving_hand, 
                              color: Color(0xFF84BD00), 
                              size: 25
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Hello ${_userService.userName ?? 'User'}',
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () async {
                          await Navigator.push(context, MaterialPageRoute(builder: (context) => const UpdateProfileScreen()));
                          if (mounted) {
                            _loadUserData();
                          }
                        },
                        child: const Text(
                          'Edit',
                          style: TextStyle(color: Color(0xFF84BD00), fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildProfileInfoRow('Email', _userService.userEmail ?? 'Not provided', isCopyable: true),
                  const SizedBox(height: 12),
                  _buildProfileInfoRow('Mobile', '${_userService.userCountryCode ?? '+91'} ${_userService.userPhone ?? 'Not provided'}', isCopyable: true),
                  const SizedBox(height: 12),
                  // Sign-Up Time and Last Log-In hidden as per request
                  // _buildProfileInfoRow('Sign-Up Time', _userService.signUpTime ?? '12/11/2025 | 12:30:45'),
                  // const SizedBox(height: 12),
                  // _buildProfileInfoRow('Last Log-In', _userService.lastLogin ?? '11/12/2025 | 11:02:12'),
                  // const SizedBox(height: 12),
                  _buildReferralCodeRow(),
                  const SizedBox(height: 12),
                  _buildLocationInfoRows(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
            _buildAssetsAllocationSection(),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildKYCTile(),
                  const SizedBox(height: 24),
                  _buildReferralHubTile(),
                  const SizedBox(height: 24),
                  _buildPartnerProgramTile(),
                  const SizedBox(height: 24),
                  _buildInviteFriendsTile(),
                  const SizedBox(height: 24),
                  _buildUpdatesTile(),
                  const SizedBox(height: 24),
                  _buildLogoutTile(),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    ],
    ),
      ),
    );
  }

  Widget _buildKYCTile() {
    final bool isCompleted = _userService.isKYCVerified();
    final bool isPending = _userService.isKYCPending();
    final bool canStart = _userService.isKYCNotStarted() || _userService.isKYCRejected();
    final bool canRestart = _userService.canRestartKYC();
    final bool needsSelfieUpload = _userService.needsSelfieUpload();
    
    final bool isNameMismatchRejection = _userService.kycStatus == 'Rejected' && 
        _userService.kycRejectionReason != null && 
        _userService.kycRejectionReason!.toLowerCase().contains('name mismatch');
    
    print('🔍 UI BUILD KYC: Status="${_userService.kycStatus}", isCompleted=$isCompleted, isPending=$isPending, canStart=$canStart, canRestart=$canRestart, needsSelfieUpload=$needsSelfieUpload, isNameMismatchRejection=$isNameMismatchRejection');

    return GestureDetector(
      onTap: () async {
        // Handle name mismatch rejection - show dialog
        if (isNameMismatchRejection) {
          _showNameMismatchDialog();
          return;
        }
        
        // Check if profile is complete before allowing KYC
        if (!isCompleted && !_userService.isProfileComplete()) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please complete your profile details first'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
          Navigator.push(
            context, 
            MaterialPageRoute(builder: (context) => const UpdateProfileScreen())
          ).then((_) {
            if (mounted) {
              _loadUserData();
            }
          });
          return;
        }
        
        // If KYC not completed, open website KYC page
        if (!isCompleted) {
          try {
            final url = Uri.parse('https://www.creddx.com/profile/kyc');
            await launchUrl(url, mode: LaunchMode.externalApplication);
            // Refresh status after user returns
            await Future.delayed(const Duration(seconds: 2));
            if (mounted) {
              _refreshKYCStatus();
            }
          } catch (e) {
            debugPrint('Error launching KYC URL: $e');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Could not open KYC page: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _userService.getKYCStatusColor().withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getKYCIcon(),
                color: _userService.getKYCStatusColor(),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: const Text(
                          'KYC Verification',
                          style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        onPressed: _refreshKYCStatus,
                        icon: const Icon(Icons.refresh, color: Color(0xFF84BD00), size: 20),
                        tooltip: 'Refresh KYC Status',
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    needsSelfieUpload ? 'Document verified - upload selfie to complete' : _getKYCDescription(),
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (isCompleted)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF84BD00).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF84BD00).withOpacity(0.5), width: 1),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified, color: Color(0xFF84BD00), size: 14),
                        SizedBox(width: 4),
                        Text(
                          'Completed',
                          style: TextStyle(color: Color(0xFF84BD00), fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            else if (isPending)
              canRestart
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF84BD00),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Restart KYC',
                          style: const TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_forward_ios, color: Colors.black, size: 10),
                      ],
                    ),
                  )
                : needsSelfieUpload
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF84BD00),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.camera_alt, color: Colors.black, size: 12),
                          const SizedBox(width: 4),
                          Text(
                            'Upload Selfie',
                            style: const TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_forward_ios, color: Colors.black, size: 10),
                        ],
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _userService.kycStatus,
                          style: TextStyle(
                            color: _userService.getKYCStatusColor(),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_userService.kycSubmittedAt != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            _userService.kycSubmittedAt!,
                            style: const TextStyle(color: Colors.white38, fontSize: 10),
                          ),
                        ],
                      ],
                    )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF84BD00),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      !_userService.isProfileComplete() && !isCompleted ? 'Complete Profile' :
                      _userService.kycStatus == 'Not Started' ? 'Complete KYC' : 
                      isNameMismatchRejection ? 'Update Profile' :
                      _userService.kycStatus == 'Rejected' ? 'Retry KYC' : 'Complete KYC',
                      style: const TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.open_in_new, color: Colors.black, size: 10),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  IconData _getKYCIcon() {
    // Check if rejection is due to name mismatch
    final bool isNameMismatchRejection = _userService.kycStatus == 'Rejected' && 
        _userService.kycRejectionReason != null && 
        _userService.kycRejectionReason!.toLowerCase().contains('name mismatch');
    
    if (isNameMismatchRejection) {
      return Icons.warning_amber;
    }
    
    switch (_userService.kycStatus) {
      case 'Completed':
        return Icons.verified;
      case 'Pending':
        return Icons.pending;
      case 'Rejected':
        return Icons.cancel;
      default:
        return Icons.fact_check;
    }
  }

  String _getKYCDescription() {
    // If KYC is pending but document not submitted, show incomplete message
    if (_userService.canRestartKYC()) {
      return 'KYC incomplete - click to restart';
    }
    
    // Check if rejection is due to name mismatch
    final bool isNameMismatchRejection = _userService.kycStatus == 'Rejected' && 
        _userService.kycRejectionReason != null && 
        _userService.kycRejectionReason!.toLowerCase().contains('name mismatch');
    
    if (isNameMismatchRejection) {
      return 'Name mismatch - Update profile for admin review';
    }
    
    switch (_userService.kycStatus) {
      case 'Completed':
        return 'Your identity has been verified';
      case 'Pending':
        return 'Verification in progress';
      case 'Rejected':
        return 'Please resubmit your documents';
      default:
        return 'Complete verification to unlock all features';
    }
  }

  void _showNameMismatchDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: const Text(
            'Name Mismatch Detected',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your KYC was rejected because the name on your documents does not match your profile name.',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 12),
              const Text(
                'Please update your profile name to match your government documents. The admin will review your updated profile.',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Text(
                'Rejection Reason: ${_userService.kycRejectionReason ?? "Unknown"}',
                style: const TextStyle(color: Colors.orange, fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Navigate to update profile screen
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const UpdateProfileScreen()),
                ).then((_) {
                  // Refresh data when returning
                  if (mounted) {
                    _loadUserData();
                    setState(() {});
                    // Show message that admin will review
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Profile updated successfully. Admin will review your updated profile.'),
                        backgroundColor: Color(0xFF84BD00),
                        duration: Duration(seconds: 4),
                      ),
                    );
                  }
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF84BD00),
              ),
              child: const Text(
                'Update Profile Name',
                style: TextStyle(color: Colors.black),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildReferralHubTile() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.hub_outlined, color: Color(0xFF84BD00), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                const Text(
                  'Referral Hub',
                  style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Coming Soon',
                  style: TextStyle(
                    color: Color(0xFF84BD00),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 14),
        ],
      ),
    );
  }

  Widget _buildPartnerProgramTile() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AffiliateProgramScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.people, color: Color(0xFF84BD00), size: 22),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Affiliate Program',
                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildInviteFriendsTile() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.person_add, color: Color(0xFF84BD00), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Invite Friends',
                  style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  'Coming Soon',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 14),
        ],
      ),
    );
  }

  Widget _buildUpdatesTile() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const UpdatesScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.system_update, color: Color(0xFF84BD00), size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Updates',
                    style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  if (_currentVersion.isNotEmpty)
                    Text(
                      'Version $_currentVersion',
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                ],
              ),
            ),
            if (_isUpdateAvailable)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF84BD00),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'NEW',
                  style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 14),
          ],
        ),
      ),
    );
  }

  
  Widget _buildLogoutTile() {
    return GestureDetector(
      onTap: () async {
        final result = await AuthService.logout();
        if (result['success'] == true) {
          if (mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const LoginScreen()),
              (route) => false,
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result['message'] ?? 'Logout failed'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.logout, color: Color(0xFFFF6B6B), size: 22),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Logout',
                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileInfoRow(String label, String value, {bool isCopyable = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 13)),
        Row(
          children: [
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
            if (isCopyable && value != 'Not provided') ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: value));
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Copied to clipboard!'),
                        backgroundColor: Color(0xFF84BD00),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                },
                child: const Icon(
                  Icons.copy,
                  color: Color(0xFF84BD00),
                  size: 16,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildReferralCodeRow() {
    final referralCode = _userService.referralCode ?? 'Loading...';
    debugPrint('🏗️ Building referral code row: $referralCode');
    debugPrint('🏗️ UserService referralCode: ${_userService.referralCode}');
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('Referral Code', style: TextStyle(color: Colors.white38, fontSize: 13)),
        Row(
          children: [
            Text(
              referralCode,
              style: const TextStyle(
                color: Color(0xFF84BD00),
                fontSize: 13,
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () async {
                // Copy referral code to clipboard
                if (referralCode != 'Loading...') {
                  await Clipboard.setData(ClipboardData(text: referralCode));
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Referral code copied!'),
                        backgroundColor: Color(0xFF84BD00),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                }
              },
              child: const Icon(
                Icons.copy,
                color: Color(0xFF84BD00),
                size: 16,
              ),
            ),
            const SizedBox(width: 4),
            // Temporary debug button
            GestureDetector(
              onTap: () async {
                await _userService.debugReferralCode();
                setState(() {}); // Refresh UI after debug
              },
              child: const Icon(
                Icons.bug_report,
                color: Colors.orange,
                size: 16,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLocationInfoRows() {
    final userId = _userService.userId;
    final country = _userService.userCountry;
    final state = _userService.userState;
    final city = _userService.userCity;
    final isFetchingLocation = _userService.isFetchingLocationNames;

    // Build location string, only include non-null and non-empty parts
    List<String> locationParts = [];
    if (city != null && city.isNotEmpty) locationParts.add(city);
    if (state != null && state.isNotEmpty) locationParts.add(state);
    if (country != null && country.isNotEmpty) locationParts.add(country);

    String locationText;
    if (locationParts.isNotEmpty) {
      locationText = locationParts.join(', ');
    } else if (isFetchingLocation) {
      locationText = 'Fetching location...';
    } else {
      locationText = 'Location not provided';
    }

    return Column(
      children: [
        _buildProfileInfoRow('User ID', userId ?? 'Not provided', isCopyable: true),
        const SizedBox(height: 12),
        _buildProfileInfoRow('Location', locationText),
      ],
    );
  }

  Widget _buildSpotHoldingsList() {
    // Get spot data from multiple sources
    final spotBalances = _walletBalances['spot']?['balances'] as List<dynamic>? ?? [];
    final spotBalanceMap = _walletBalances['spotBalance'] is Map ? _walletBalances['spotBalance'] as Map<String, dynamic>? : {};
    final spotRawAssets = _walletBalances['spot_raw'] as List<dynamic>? ?? [];
    final spotAssets = _walletBalances['spot_assets'] as List<dynamic>? ?? [];

    // Also get from UnifiedWalletService
    final unifiedSpotAssets = unified.UnifiedWalletService.walletBalance?.spotAssets ?? {};

    // Combine data from all sources for comprehensive display
    final Map<String, double> combinedHoldings = {};

    // Helper to add to combinedHoldings
    void addToHoldings(String? coin, double amount) {
      if (coin != null && coin.isNotEmpty) {
        final symbol = coin.toUpperCase();
        combinedHoldings[symbol] = (combinedHoldings[symbol] ?? 0.0) + amount;
      }
    }

    // Add from spotBalances list
    for (final balance in spotBalances) {
      if (balance is Map) {
        final coin = balance['coin']?.toString() ?? balance['asset']?.toString();
        final available = double.tryParse(balance['available']?.toString() ?? '0') ?? 0.0;
        final locked = double.tryParse(balance['locked']?.toString() ?? '0') ?? 0.0;
        addToHoldings(coin, available + locked);
      }
    }

    // Add from spotBalanceMap
    spotBalanceMap?.forEach((coin, value) {
      final amount = double.tryParse(value.toString()) ?? 0.0;
      addToHoldings(coin, amount);
    });

    // Add from spotRawAssets
    for (final asset in spotRawAssets) {
      if (asset is Map) {
        final coin = asset['asset']?.toString() ?? asset['coin']?.toString();
        final available = double.tryParse(asset['available']?.toString() ?? '0') ?? 0.0;
        final locked = double.tryParse(asset['locked']?.toString() ?? '0') ?? 0.0;
        addToHoldings(coin, available + locked);
      }
    }

    // Add from spotAssets list
    for (final asset in spotAssets) {
      if (asset is Map) {
        final coin = asset['asset']?.toString() ?? asset['coin']?.toString();
        final available = double.tryParse(asset['available']?.toString() ?? '0') ?? 0.0;
        final locked = double.tryParse(asset['locked']?.toString() ?? '0') ?? 0.0;
        addToHoldings(coin, available + locked);
      }
    }

    // Add from UnifiedWalletService spotAssets Map
    unifiedSpotAssets.forEach((coin, data) {
      double amount = 0.0;
      if (data is num) {
        amount = data.toDouble();
      } else if (data is Map) {
        final val = data['total'] ?? data['balance'] ?? data['available'] ?? data['free'] ?? '0';
        amount = double.tryParse(val.toString()) ?? 0.0;
      }
      addToHoldings(coin, amount);
    });

    // For USDT, add total balance from all wallets (main + spot + p2p + bot)
    // This ensures spot USDT shows the same as Coin view USDT (total across all wallets)
    double totalUSDT = 0.0;
    // 1. Try UnifiedWalletService (most accurate)
    totalUSDT = unified.UnifiedWalletService.totalUSDTBalance;
    // 2. Try pre-calculated aggregated fields from _fetchWalletBalances
    if (totalUSDT == 0.0) {
      totalUSDT = _mainUSDT + _spotUSDT + _p2pUSDT + _botUSDT + _holdingUSDT;
    }
    // 3. Try local _walletBalances map
    if (totalUSDT == 0.0) {
      final data = _walletBalances;
      final usdtVal = data['usdt'] ?? data['USDT'] ?? data['usdt_balance'] ?? data['balance'];
      if (usdtVal != null) {
        if (usdtVal is num) totalUSDT = usdtVal.toDouble();
        else if (usdtVal is String) totalUSDT = double.tryParse(usdtVal) ?? 0.0;
      }
    }
    // 4. Try _apiWalletBalances as a last resort
    if (totalUSDT == 0.0 && _apiWalletBalances.isNotEmpty) {
      totalUSDT = _extractUSDTFromWalletData(_apiWalletBalances['main']) +
                  _extractUSDTFromWalletData(_apiWalletBalances['spot']) +
                  _extractUSDTFromWalletData(_apiWalletBalances['p2p']) +
                  _extractUSDTFromWalletData(_apiWalletBalances['bot'] ?? _apiWalletBalances['demo_bot']) +
                  _extractUSDTFromWalletData(_apiWalletBalances['holding']);
    }
    // Add the total USDT to combined holdings (this will show total USDT in spot section)
    if (totalUSDT > 0) {
      addToHoldings('USDT', totalUSDT);
    }

    // Get all coins: system coins + coins with holdings
    // Include ALL coins from the system, even with 0 balance
    final Set<String> allCoinsSet = {};

    // Add all system coins from API
    if (_allSystemCoins.isNotEmpty) {
      allCoinsSet.addAll(_allSystemCoins);
    }

    // Add coins with actual balances
    allCoinsSet.addAll(combinedHoldings.keys);

    // Add default coins if no system coins available yet
    if (allCoinsSet.isEmpty) {
      allCoinsSet.addAll(['USDT', 'BTC', 'ETH', 'USDC', 'BNB']);
    }

    // Remove INR from spot
    allCoinsSet.remove('INR');
    allCoinsSet.remove('inr');

    final List<String> allCoins = allCoinsSet.toList();

    // Sort: Priority coins first, then by balance descending, then alphabetical
    final List<String> priorityCoins = ['USDT', 'BTC', 'ETH', 'USDC', 'BNB', 'ADA', 'SOL', 'DOT', 'XRP', 'MATIC'];
    allCoins.sort((a, b) {
      final aPriority = priorityCoins.indexOf(a);
      final bPriority = priorityCoins.indexOf(b);

      if (aPriority != -1 || bPriority != -1) {
        if (aPriority != -1 && bPriority != -1) return aPriority.compareTo(bPriority);
        return aPriority != -1 ? -1 : 1;
      }

      final aBalance = combinedHoldings[a] ?? 0.0;
      final bBalance = combinedHoldings[b] ?? 0.0;
      if (bBalance != aBalance) return bBalance.compareTo(aBalance);
      return a.compareTo(b);
    });

    // Build rows for each coin
    return Column(
      children: allCoins.asMap().entries.map((entry) {
        final index = entry.key;
        final coin = entry.value;
        final balance = combinedHoldings[coin] ?? 0.0;
        final isLast = index == allCoins.length - 1;

        String formattedBalance;
        if (_isWalletHidden) {
          formattedBalance = '***';
        } else if (coin == 'INR') {
          formattedBalance = balance.toStringAsFixed(2);
        } else if (coin == 'BTC') {
          formattedBalance = balance.toStringAsFixed(8);
        } else {
          formattedBalance = balance.toStringAsFixed(6);
        }

        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    coin,
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ),
                SizedBox(
                  width: 120,
                  child: Text(
                    _isWalletHidden ? '*** $coin' : '$formattedBalance $coin',
                    style: const TextStyle(color: Color(0xFF84BD00), fontSize: 14, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
            if (!isLast) const Divider(color: Colors.white10, height: 16),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildWalletRow(String walletType, String balance) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(walletType, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
        Text(balance, style: const TextStyle(color: Color(0xFF84BD00), fontSize: 14, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildExpandableSection({
    required String title,
    required bool isExpanded,
    required VoidCallback onTap,
    required Widget content,
  }) {
    return Column(
      children: [
        ListTile(
          onTap: onTap,
          title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          trailing: Icon(
            isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
            color: Colors.white54,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
        ),
        if (isExpanded) content,
      ],
    );
  }

  Widget _buildToggleButton(String title, bool isSelected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF007AFF) : const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        title,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.white54,
          fontSize: 14,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    );
  }

  
  Widget _buildAssetsAllocationSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(0),
        border: Border.symmetric(
          horizontal: BorderSide(color: const Color(0xFF84BD00).withOpacity(0.3), width: 1.5),
        ),
      ),
      child: Column(
        children: [
          // Header with tap to expand/collapse
          GestureDetector(
            onTap: () => setState(() => _isAssetsAllocationExpanded = !_isAssetsAllocationExpanded),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF84BD00).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.account_balance_wallet, color: Color(0xFF84BD00), size: 28),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      'Assets Allocation',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Icon(
                    _isAssetsAllocationExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: Colors.white54,
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
          // Expandable content
          if (_isAssetsAllocationExpanded) _buildAssetsAllocationContent(),
        ],
      ),
    );
  }

  Widget _buildAssetsAllocationContent() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => setState(() => _selectedView = 'wallet'),
                  child: _buildToggleButton('Wallet', _selectedView == 'wallet'),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => setState(() => _selectedView = 'coin'),
                  child: _buildToggleButton('Coin', _selectedView == 'coin'),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    setState(() => _selectedView = 'spot');
                    // Refresh spot data when switching to spot view
                    _refreshSpotData();
                  },
                  child: _buildToggleButton('Spot', _selectedView == 'spot'),
                ),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: _refreshAssetData,
                  child: Icon(
                    Icons.refresh,
                    color: Colors.white54,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => setState(() => _isWalletHidden = !_isWalletHidden),
                  child: Icon(
                    _isWalletHidden ? Icons.visibility_off : Icons.visibility,
                    color: Colors.white54,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Headers
          Row(
            children: [
              const Expanded(
                flex: 2,
                child: Text('Account', style: TextStyle(color: Colors.white54, fontSize: 11)),
              ),
              const SizedBox(
                width: 80,
                child: Text('Total Balance', style: TextStyle(color: Colors.white54, fontSize: 11)),
              ),
              const SizedBox(width: 4),
              const SizedBox(
                width: 50,
                child: Text('Actions', style: TextStyle(color: Colors.white54, fontSize: 11), textAlign: TextAlign.right),
              ),
            ],
          ),
          const Divider(color: Colors.white10, height: 24),
          if (_isLoadingWallet || _isLoadingAssetPrices)
            const Center(
              child: SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(color: Color(0xFF84BD00), strokeWidth: 2),
              ),
            )
          else ...[
            ...(() {
              if (_selectedView == 'spot') {
                return [_buildSpotHoldingsList()];
              }
              final items = _selectedView == 'wallet'
                ? ['INR', 'Main', 'SPOT', 'P2P', 'Bot']
                : ['INR', 'USDT'];
              return items.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                final balance = _selectedView == 'wallet'
                  ? _getWalletBalance(item)
                  : _getCoinBalance(item);
                final isLast = index == items.length - 1;

                return Column(
                  children: [
                    _buildWalletRow(item, balance),
                    if (!isLast) const Divider(color: Colors.white10, height: 16),
                  ],
                );
              }).toList();
            })(),
          ],
        ],
      ),
    );
  }

  String _getWalletBalance(String walletType) {
    if (_isLoadingWallet && !unified.UnifiedWalletService.isInitialized) return '...';

    // Use UnifiedWalletService like wallet screen
    double total = 0.0;
    String currency = 'USDT';

    switch (walletType.toUpperCase()) {
      case 'MAIN':
        total = unified.UnifiedWalletService.mainUSDTBalance;
        if (total == 0.0) total = _mainUSDT;
        break;
      case 'SPOT':
        total = unified.UnifiedWalletService.spotUSDTBalance;
        if (total == 0.0) total = _spotUSDT;
        break;
      case 'P2P':
        total = unified.UnifiedWalletService.p2pUSDTBalance;
        if (total == 0.0) total = _p2pUSDT;
        break;
      case 'BOT':
        total = unified.UnifiedWalletService.botUSDTBalance;
        if (total == 0.0) total = _botUSDT;
        break;
      case 'INR':
        currency = 'INR';
        total = unified.UnifiedWalletService.mainINRBalance;
        // Fallback to socket data if unified service returns 0
        if (total == 0.0) {
          final socketInr = _walletBalances['inr'] ?? _walletBalances['INR'] ?? _walletBalances['inr_available'] ?? _walletBalances['inr_total'];
          if (socketInr != null) {
            total = double.tryParse(socketInr.toString()) ?? 0.0;
          }
        }
        break;
    }

    if (_isWalletHidden) return '*** $currency';
    return '${total.toStringAsFixed(2)} $currency';
  }
  
  String _getCoinBalance(String coin) {
    double total = 0.0;
    
    if (coin == 'INR') {
      total = unified.UnifiedWalletService.totalINRBalance;
      if (total == 0.0) {
        // Fallback to local _walletBalances map
        final inrVal = _walletBalances['inr'] ?? _walletBalances['INR'] ?? 0.0;
        total = double.tryParse(inrVal.toString()) ?? 0.0;
      }
    } else if (coin == 'USDT') {
      // 1. Try UnifiedWalletService (most accurate)
      total = unified.UnifiedWalletService.totalUSDTBalance;
      
      // 2. Try pre-calculated aggregated fields from _fetchWalletBalances
      if (total == 0.0) {
        total = _mainUSDT + _spotUSDT + _p2pUSDT + _botUSDT + _holdingUSDT;
      }
      
      // 3. Try local _walletBalances map thoroughly
      if (total == 0.0) {
        final data = _walletBalances;
        
        // Try common top-level keys
        final usdtVal = data['usdt'] ?? data['USDT'] ?? data['usdt_balance'] ?? data['balance'];
        if (usdtVal != null) {
          if (usdtVal is num) total = usdtVal.toDouble();
          else if (usdtVal is String) total = double.tryParse(usdtVal) ?? 0.0;
        }
        
        // Try mainBalance nested key
        if (total == 0.0 && data['mainBalance'] is Map) {
          final main = data['mainBalance'] as Map;
          final val = main['USDT'] ?? main['usdt'];
          if (val != null) {
            if (val is num) total = val.toDouble();
            else if (val is Map) total = double.tryParse(val['total']?.toString() ?? val['available']?.toString() ?? '0') ?? 0.0;
          }
        }
        
        // Try summing across different wallets if present in _walletBalances
        if (total == 0.0) {
          final keys = ['main', 'spot', 'p2p', 'bot'];
          for (var key in keys) {
            if (data[key] is Map) {
              final w = data[key] as Map;
              final bal = w['usdt'] ?? w['USDT'] ?? w['balance'];
              if (bal != null) total += double.tryParse(bal.toString()) ?? 0.0;
            }
          }
        }
      }

      // 4. Try _apiWalletBalances as a last resort
      if (total == 0.0 && _apiWalletBalances.isNotEmpty) {
        total = _extractUSDTFromWalletData(_apiWalletBalances['main']) +
                _extractUSDTFromWalletData(_apiWalletBalances['spot']) +
                _extractUSDTFromWalletData(_apiWalletBalances['p2p']) +
                _extractUSDTFromWalletData(_apiWalletBalances['bot'] ?? _apiWalletBalances['demo_bot']) +
                _extractUSDTFromWalletData(_apiWalletBalances['holding']);
      }
    }

    if (_isWalletHidden) return '*** $coin';
    
    // If still 0 and loading, show dots
    if (total == 0.0 && _isLoadingWallet) return '...';
    
    return '${total.toStringAsFixed(2)} $coin';
  }
  
}
