import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:upgrader/upgrader.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/auth_service.dart';
import '../services/p2p_service.dart';
import '../services/socket_service.dart';
import '../services/spot_service.dart';
import '../services/unified_wallet_service.dart' as unified;
import '../services/user_service.dart';
import '../services/wallet_service.dart';
import 'login_screen.dart';
import 'partner_program_screen.dart'; // Affiliate Program
import 'update_profile_screen.dart';
import 'updates_screen.dart';

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
  static const String _inrToUsdtApiUrl = 'https://api11.hathmetech.com/api/wallet/v1/inr/convert/inr-to-usdt';
  static const String _usdtToInrApiUrl = 'https://api11.hathmetech.com/api/wallet/v1/inr/convert/usdt-to-inr';
  
  static const String _wsBaseUrl = 'wss://api4.creddx.com/ws';
  static const String _httpBaseUrl = 'https://api11.hathmetech.com';

  @override
  void initState() {
    super.initState();
    
    // Load user data and check KYC status immediately when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserData();
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
      final result = await WalletService.getWalletBalance();
      if (result['success'] == true && result['data'] != null) {
        final data = result['data'];
        setState(() {
          _mainUSDT = _extractUSDTFromWalletData(data['main']);
          _spotUSDT = _extractUSDTFromWalletData(data['spot']);
          _p2pUSDT = _extractUSDTFromWalletData(data['p2p']);
          _botUSDT = _extractUSDTFromWalletData(data['bot'] ?? data['demo_bot']);
          _holdingUSDT = _extractUSDTFromWalletData(data['holding']);
          _isLoadingWallet = false;
        });

        // Aggressive grand total fetch as fallback
        final grandTotal = await WalletService.getTotalUSDTBalance();
        if (mounted && grandTotal > 0 && (_mainUSDT + _spotUSDT + _p2pUSDT + _botUSDT + _holdingUSDT) == 0) {
          setState(() {
            _mainUSDT = grandTotal;
          });
        }
      } else {
        setState(() {
          _isLoadingWallet = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching wallet balances: $e');
      setState(() {
        _isLoadingWallet = false;
      });
    }
  }

  // Helper to extract USDT balance from wallet data
  double _extractUSDTFromWalletData(dynamic walletData) {
    if (walletData == null) return 0.0;
    if (walletData is num) return walletData.toDouble();
    if (walletData is String) return double.tryParse(walletData) ?? 0.0;

    if (walletData is Map) {
      final usdt = walletData['USDT'] ?? walletData['usdt'];
      if (usdt != null) {
        if (usdt is num) return usdt.toDouble();
        if (usdt is String) return double.tryParse(usdt) ?? 0.0;
        if (usdt is Map) {
          final val = usdt['total'] ?? usdt['balance'] ?? usdt['available'] ?? usdt['free'] ?? usdt['amount'] ?? '0';
          return double.tryParse(val.toString()) ?? 0.0;
        }
      }

      if (walletData['balances'] is List) {
        final balances = walletData['balances'] as List;
        for (var b in balances) {
          if (b is Map && (b['coin']?.toString().toUpperCase() == 'USDT' || b['asset']?.toString().toUpperCase() == 'USDT')) {
            final val = b['total'] ?? b['balance'] ?? b['available'] ?? b['free'] ?? b['amount'] ?? '0';
            return double.tryParse(val.toString()) ?? 0.0;
          }
        }
      }

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
      await unified.UnifiedWalletService.initialize();
      await unified.UnifiedWalletService.refreshWalletSummary();
      await unified.UnifiedWalletService.refreshBotBalance();
      
      final inrBalance = unified.UnifiedWalletService.mainINRBalance;
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
    _unifiedWalletSubscription = unified.UnifiedWalletService.walletBalanceStream.listen((walletBalance) {
      if (mounted) {
        setState(() {
          _isLoadingWallet = walletBalance == null;
        });
      }
    });

    _balanceSubscription = SocketService.balanceStream.listen((data) {
      final eventType = data['type'];
      if (eventType == 'balance_update' || eventType == 'wallet_summary') {
        final payload = data['data'] ?? data;
        if (eventType == 'wallet_summary' && payload is Map) {
          final mainBalance = payload['mainBalance'] ?? payload['main'];
          if (mainBalance is Map) {
            final inrVal = mainBalance['INR'] ?? mainBalance['inr'] ?? mainBalance['Inr'];
            if (inrVal != null) {
              final inrAmount = double.tryParse(inrVal.toString()) ?? 0.0;
              if (mounted) {
                setState(() {
                  _walletBalances['inr'] = inrAmount;
                  _walletBalances['INR'] = inrAmount;
                  _isLoadingWallet = false;
                });
              }
            }
          }
        }

        if (payload['assets'] != null) {
          final assets = payload['assets'] as List<dynamic>?;
          if (assets != null && assets.isNotEmpty) {
            final mappedAssets = assets.map((a) => {
              'coin': a['asset'],
              'available': a['available'],
              'locked': a['locked'],
            }).toList();

            if (mounted) {
              setState(() {
                _walletBalances['spot'] = {'balances': mappedAssets};
                _walletBalances['spotBalance'] = mappedAssets;
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

        if (payload['asset']?.toString().toUpperCase() == 'INR' ||
            payload['inr_available'] != null ||
            payload['inr'] != null) {
          final inrAvailable = double.tryParse(
            payload['inr_available']?.toString() ??
            payload['available']?.toString() ??
            payload['inr']?.toString() ?? '0'
          ) ?? 0.0;

          if (mounted) {
            setState(() {
              _walletBalances['inr'] = inrAvailable;
              _walletBalances['INR'] = inrAvailable;
              _isLoadingWallet = false;
            });
          }
        }
      }
    });
  }
  
  Future<void> _loadConversionRate() async {
    try {
      final token = await AuthService.getToken();
      final inrResponse = await http.get(
        Uri.parse(_inrToUsdtApiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));
      
      final usdtResponse = await http.get(
        Uri.parse(_usdtToInrApiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));
      
      double newInrToUsdtRate = 52.0;
      double newUsdtToInrRate = 1.0 / 52.0;
      
      if (inrResponse.statusCode == 200) {
        final data = json.decode(inrResponse.body);
        if (data['success'] == true && data['data'] != null) {
          final rateData = data['data'];
          // Rate loaded but not directly used in UI currently
          double.tryParse((rateData['rate'] ?? rateData['conversion_rate'] ?? rateData['inr_to_usdt']).toString());
        }
      }
      
      if (usdtResponse.statusCode == 200) {
        final data = json.decode(usdtResponse.body);
        if (data['success'] == true && data['data'] != null) {
          final rateData = data['data'];
          // Rate loaded but not directly used in UI currently
          double.tryParse((rateData['rate'] ?? rateData['conversion_rate'] ?? rateData['usdt_to_inr']).toString());
        }
      }
    } catch (e) {
      debugPrint('Error loading conversion rates: $e');
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
  
  List<String> _getAllCoinsWithBalances() {
    final Set<String> coinSet = {'INR', 'USDT'};
    if (_allSystemCoins.isNotEmpty) coinSet.addAll(_allSystemCoins);
    final data = _walletBalances;
    
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
    
    checkWallet(data['main']);
    checkWallet(data['spot']);
    checkWallet(data['p2p']);
    checkWallet(data['bot']);
    
    data.forEach((key, value) {
      if (value is num && value > 0) {
        final coin = key.toUpperCase();
        if (coin.length <= 5) coinSet.add(coin);
      }
    });

    final result = coinSet.toList();
    result.sort((a, b) {
      if (a == 'INR') return -1;
      if (b == 'INR') return 1;
      if (a == 'USDT') return -1;
      if (b == 'USDT') return 1;
      return a.compareTo(b);
    });
    return result;
  }

  Future<void> _refreshAssetData() async {
    setState(() {
      _isLoadingWallet = true;
      _isLoadingAssetPrices = true;
    });
    await Future.wait([_loadAllWalletData(), _loadAssetPrices()]);
  }

  Future<void> _refreshSpotData() async {
    setState(() {
      _isLoadingWallet = true;
    });
    try {
      final spotResult = await SpotService.getBalance(forceRefresh: true);
      if (spotResult['success'] == true && spotResult['data'] != null) {
        final data = spotResult['data'];
        if (data is Map) {
          setState(() {
            final rawAssets = data['raw_assets'] as List?;
            if (rawAssets != null) {
              _allWalletData['spot_raw'] = rawAssets.where((a) {
                final assetName = (a['asset']?.toString().toUpperCase() ?? a['coin']?.toString().toUpperCase());
                return assetName?.isNotEmpty ?? false;
              }).toList();
            }
            final assetsMap = data['assets'] as Map?;
            if (assetsMap != null) {
              _allWalletData['assets'] = assetsMap;
            }
            _walletBalances = _allWalletData;
            _isLoadingWallet = false;
          });
        }
      } else {
        setState(() {
          _isLoadingWallet = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingWallet = false;
      });
    }
  }

  Future<void> _loadAllWalletData() async {
    if (!mounted) return;
    setState(() {
      _isLoadingWallet = true;
    });

    try {
      Map<String, dynamic> aggregatedData = {};
      final existingInr = _walletBalances['inr'] ?? _walletBalances['INR'] ??
                          _walletBalances['inr_available'] ?? _walletBalances['INR_available'];
      
      final userResult = await UserService.getUserAssets();
      if (userResult['success'] == true && userResult['data'] != null) {
        final data = userResult['data'];
        if (data is Map) {
          final filteredData = Map<String, dynamic>.from(data);
          filteredData.removeWhere((key, value) => key.toLowerCase().contains('inr'));
          aggregatedData.addAll(filteredData);
        }
      }

      final walletResult = await WalletService.getAllWalletBalances();
      if (walletResult['success'] == true && walletResult['data'] != null) {
        final data = walletResult['data'];
        if (data is Map) {
          data.forEach((key, value) {
            if (!key.toLowerCase().contains('inr')) aggregatedData[key] = value;
          });
        }
      }

      final spotResult = await SpotService.getBalance();
      if (spotResult['success'] == true && spotResult['data'] != null) {
        final data = spotResult['data'];
        if (data is Map) {
          final assetsData = data['assets'];
          if (assetsData is List) {
            aggregatedData['spot_assets'] = assetsData.where((a) => 
              (a['asset']?.toString().toUpperCase() ?? a['coin']?.toString().toUpperCase())?.isNotEmpty ?? false
            ).toList();
          }
          final rawAssets = data['raw_assets'] as List?;
          if (rawAssets != null) {
            aggregatedData['spot_raw'] = rawAssets.where((a) =>
              (a['asset']?.toString().toUpperCase() ?? a['coin']?.toString().toUpperCase())?.isNotEmpty ?? false
            ).toList();
          }
          data.forEach((key, value) {
            if (!aggregatedData.containsKey(key) && !key.toLowerCase().contains('inr')) {
              aggregatedData[key] = value;
            }
          });
        }
      }

      if (existingInr != null) {
        aggregatedData['inr'] = existingInr;
        aggregatedData['INR'] = existingInr;
      }

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
      setState(() {
        _isLoadingWallet = false;
      });
    }
  }
  
  Future<void> _loadAssetPrices() async {
    try {
      setState(() {
        _assetPrices = {
          'BTC': 43500.00, 'ETH': 2250.00, 'USDT': 1.00, 'USDC': 1.00,
          'BNB': 310.00, 'ADA': 0.45, 'SOL': 98.00, 'DOT': 7.20,
        };
        _isLoadingAssetPrices = false;
      });
    } catch (e) {
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
    await _userService.initUserData();
    if (mounted) setState(() {});
    await _userService.fetchReferralCode(onReferralCodeLoaded: () {
      if (mounted) setState(() { _referralCode = _userService.referralCode; });
    });
    _startRealTimeStatusCheck();
  }

  Future<void> _refreshKYCStatus() async {
    if (mounted) setState(() { _isLoading = true; });
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white))),
              SizedBox(width: 16),
              Text('Refreshing KYC status...'),
            ],
          ),
          backgroundColor: Color(0xFF84BD00),
          duration: Duration(seconds: 2),
        ),
      );
      String previousStatus = _userService.kycStatus;
      await _userService.fetchProfileDataFromAPI();
      String currentStatus = _userService.kycStatus;
      
      if (previousStatus == currentStatus && currentStatus == 'Pending') {
        final kycCheckResult = await _userService.checkKYCStatusPost();
        if (kycCheckResult['error'] != null && 
            (kycCheckResult['error'].toString().toLowerCase().contains('limit') ||
             kycCheckResult['error'].toString().toLowerCase().contains('429'))) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('API limit reached. Status will update once processed.'), backgroundColor: Colors.orange, duration: Duration(seconds: 4)),
          );
          return;
        }
      }
      
      final color = _userService.getKYCStatusColor();
      final message = 'KYC status refreshed: $currentStatus';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  Future<void> _loadTrustedDevices() async {
    try {
      final devices = await P2PService.getTrustedDevices();
      setState(() {
        _trustedDevices = devices;
        _isLoadingDevices = false;
      });
    } catch (e) {
      setState(() {
        _trustedDevices = [];
        _isLoadingDevices = false;
      });
    }
  }

  void _startRealTimeStatusCheck() {
    _stopRealTimeKYCUpdates();
    _kycStatusUpdateTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      try {
        await _userService.fetchProfileDataFromAPI();
        if (mounted) setState(() {});
      } catch (e) {
        debugPrint('Error in real-time status check: $e');
      }
    });
  }

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
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProfileHeader(),
              const SizedBox(height: 24),
              _buildInfoSection(),
              const SizedBox(height: 24),
              _buildAssetsAllocationSection(),
              const SizedBox(height: 24),
              _buildAccountSecuritySection(),
              const SizedBox(height: 24),
              _buildPromotionsSection(),
              const SizedBox(height: 24),
              _buildGeneralSection(),
              const SizedBox(height: 40),
              _buildLogoutButton(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Row(
        children: [
          Image.asset(
            'assets/images/Hello!.gif',
            width: 60,
            height: 60,
            errorBuilder: (_, __, ___) => Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF84BD00), width: 1),
              ),
              child: const Icon(Icons.person, color: Color(0xFF84BD00), size: 30),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hello, ${_userService.userName ?? 'User'}',
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 4),
                Text(
                  'User ID: ${_userService.userId ?? 'N/A'}',
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (context) => const UpdateProfileScreen()));
              _loadUserData();
            },
            icon: const Icon(Icons.edit_note, color: Color(0xFF84BD00), size: 28),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF333333)),
      ),
      child: Column(
        children: [
          _buildInfoRow(Icons.email_outlined, 'Email', _userService.userEmail ?? 'Not provided', isCopyable: true),
          const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(color: Color(0xFF333333), height: 1)),
          _buildInfoRow(Icons.phone_outlined, 'Mobile', '${_userService.userCountryCode ?? '+91'} ${_userService.userPhone ?? 'Not provided'}', isCopyable: true),
          const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(color: Color(0xFF333333), height: 1)),
          _buildReferralRow(),
          const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(color: Color(0xFF333333), height: 1)),
          _buildLocationRow(),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {bool isCopyable = false}) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF84BD00), size: 18),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 14)),
        const Spacer(),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
        if (isCopyable && value != 'Not provided') ...[
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied!'), duration: Duration(seconds: 1)));
            },
            child: const Icon(Icons.copy, color: Color(0xFF84BD00), size: 16),
          ),
        ],
      ],
    );
  }

  Widget _buildReferralRow() {
    final code = _userService.referralCode ?? 'Loading...';
    return Row(
      children: [
        const Icon(Icons.card_giftcard, color: Color(0xFF84BD00), size: 18),
        const SizedBox(width: 12),
        const Text('Referral Code', style: TextStyle(color: Colors.white54, fontSize: 14)),
        const Spacer(),
        Text(code, style: const TextStyle(color: Color(0xFF84BD00), fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () {
            if (code != 'Loading...') {
              Clipboard.setData(ClipboardData(text: code));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied!'), duration: Duration(seconds: 1)));
            }
          },
          child: const Icon(Icons.copy, color: Color(0xFF84BD00), size: 16),
        ),
      ],
    );
  }

  Widget _buildLocationRow() {
    List<String> parts = [];
    if (_userService.userCity?.isNotEmpty == true) parts.add(_userService.userCity!);
    if (_userService.userState?.isNotEmpty == true) parts.add(_userService.userState!);
    if (_userService.userCountry?.isNotEmpty == true) parts.add(_userService.userCountry!);
    final location = parts.isEmpty ? (_userService.isFetchingLocationNames ? 'Fetching...' : 'Not provided') : parts.join(', ');

    return Row(
      children: [
        const Icon(Icons.location_on_outlined, color: Color(0xFF84BD00), size: 18),
        const SizedBox(width: 12),
        const Text('Location', style: TextStyle(color: Colors.white54, fontSize: 14)),
        const Spacer(),
        Expanded(child: Text(location, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500), textAlign: TextAlign.right, overflow: TextOverflow.ellipsis)),
      ],
    );
  }

  Widget _buildAssetsAllocationSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF333333)),
      ),
      child: Column(
        children: [
          ListTile(
            onTap: () => setState(() => _isAssetsAllocationExpanded = !_isAssetsAllocationExpanded),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: const Color(0xFF84BD00).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.account_balance_wallet, color: Color(0xFF84BD00), size: 20),
            ),
            title: const Text('Assets Allocation', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            trailing: Icon(_isAssetsAllocationExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: Colors.white54),
          ),
          if (_isAssetsAllocationExpanded) _buildAssetsAllocationContent(),
        ],
      ),
    );
  }

  Widget _buildAssetsAllocationContent() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildMiniToggle('Wallet', _selectedView == 'wallet', () => setState(() => _selectedView = 'wallet')),
                      const SizedBox(width: 8),
                      _buildMiniToggle('Coin', _selectedView == 'coin', () => setState(() => _selectedView = 'coin')),
                      const SizedBox(width: 8),
                      _buildMiniToggle('Spot', _selectedView == 'spot', () { setState(() => _selectedView = 'spot'); _refreshSpotData(); }),
                    ],
                  ),
                ),
              ),
              IconButton(onPressed: _refreshAssetData, icon: const Icon(Icons.refresh, color: Colors.white54, size: 20)),
              IconButton(onPressed: () => setState(() => _isWalletHidden = !_isWalletHidden), icon: Icon(_isWalletHidden ? Icons.visibility_off : Icons.visibility, color: Colors.white54, size: 20)),
            ],
          ),
          const SizedBox(height: 20),
          if (_isLoadingWallet || _isLoadingAssetPrices)
            const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: Color(0xFF84BD00), strokeWidth: 2)))
          else
            _selectedView == 'spot' ? _buildSpotHoldingsList() : _buildWalletOrCoinList(),
        ],
      ),
    );
  }

  Widget _buildMiniToggle(String title, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF84BD00) : const Color(0xFF333333),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(title, style: TextStyle(color: isSelected ? Colors.black : Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildWalletOrCoinList() {
    final items = _selectedView == 'wallet' ? ['INR', 'Main', 'SPOT', 'P2P', 'Bot'] : ['INR', 'USDT'];
    return Column(
      children: items.map((item) {
        final balance = _selectedView == 'wallet' ? _getWalletBalance(item) : _getCoinBalance(item);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(item, style: const TextStyle(color: Colors.white70, fontSize: 14)),
              Text(balance, style: const TextStyle(color: Color(0xFF84BD00), fontSize: 14, fontWeight: FontWeight.bold)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAccountSecuritySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8), child: Text('ACCOUNT & SECURITY', style: TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2))),
        _buildKYCTile(),
      ],
    );
  }

  Widget _buildKYCTile() {
    final bool isCompleted = _userService.isKYCVerified();
    final bool isPending = _userService.isKYCPending();
    final bool isRejected = _userService.isKYCRejected();
    final bool needsSelfie = _userService.needsSelfieUpload();
    final bool isNameMismatch = isRejected && (_userService.kycRejectionReason?.toLowerCase().contains('name mismatch') ?? false);
    final color = _userService.getKYCStatusColor();

    return _buildActionTile(
      icon: _getKYCIcon(),
      iconColor: color,
      title: 'KYC Verification',
      subtitle: needsSelfie ? 'Upload selfie to complete' : _getKYCDescription(),
      trailing: _buildKYCTrailing(isCompleted, isPending, isRejected, needsSelfie, isNameMismatch),
      onTap: () async {
        if (isNameMismatch) { _showNameMismatchDialog(); return; }
        if (!isCompleted && !_userService.isProfileComplete()) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please complete your profile first'), backgroundColor: Colors.orange));
          Navigator.push(context, MaterialPageRoute(builder: (context) => const UpdateProfileScreen())).then((_) => _loadUserData());
          return;
        }
        if (!isCompleted) {
          final url = Uri.parse('https://www.creddx.com/profile/kyc');
          if (await canLaunchUrl(url)) { await launchUrl(url, mode: LaunchMode.externalApplication); await Future.delayed(const Duration(seconds: 2)); _refreshKYCStatus(); }
        }
      },
    );
  }

  Widget _buildKYCTrailing(bool isCompleted, bool isPending, bool isRejected, bool needsSelfie, bool isNameMismatch) {
    if (isCompleted) return _buildStatusBadge('Completed', const Color(0xFF84BD00));
    if (needsSelfie) return _buildActionButton('Upload Selfie', const Color(0xFF84BD00));
    if (isPending) return _buildStatusBadge('Pending', Colors.orange);
    return _buildActionButton(isNameMismatch ? 'Update Profile' : isRejected ? 'Retry KYC' : 'Verify', const Color(0xFF84BD00));
  }

  Widget _buildStatusBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.5))),
      child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildActionButton(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: const TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildPromotionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8), child: Text('PROMOTIONS', style: TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2))),
        _buildActionTile(icon: Icons.people_outline, title: 'Affiliate Program', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AffiliateProgramScreen()))),
        _buildActionTile(icon: Icons.hub_outlined, title: 'Referral Hub', subtitle: 'Coming Soon', isAvailable: false),
        _buildActionTile(icon: Icons.person_add_outlined, title: 'Invite Friends', subtitle: 'Coming Soon', isAvailable: false),
      ],
    );
  }

  Widget _buildGeneralSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8), child: Text('GENERAL', style: TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2))),
        _buildActionTile(icon: Icons.system_update_outlined, title: 'Updates', subtitle: 'Version $_currentVersion', trailing: _isUpdateAvailable ? _buildStatusBadge('NEW', const Color(0xFF84BD00)) : null, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const UpdatesScreen()))),
        _buildActionTile(icon: Icons.info_outline, title: 'About Creddx', onTap: _showAboutCreddxDialog),
        _buildActionTile(icon: Icons.description_outlined, title: 'Licences', onTap: _showLicencesDialog),
      ],
    );
  }

  Widget _buildActionTile({required IconData icon, Color? iconColor, required String title, String? subtitle, Widget? trailing, VoidCallback? onTap, bool isAvailable = true}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
      decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF333333))),
      child: ListTile(
        onTap: isAvailable ? onTap : null,
        leading: Icon(icon, color: iconColor ?? const Color(0xFF84BD00), size: 22),
        title: Text(title, style: TextStyle(color: isAvailable ? Colors.white : Colors.white38, fontSize: 15, fontWeight: FontWeight.w600)),
        subtitle: subtitle != null ? Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 12)) : null,
        trailing: trailing ?? const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 14),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton(
          onPressed: () async {
            final res = await AuthService.logout();
            if (res['success'] == true) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginScreen()), (r) => false);
          },
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A1A1A), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFFF6B6B), width: 1))),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.logout, color: Color(0xFFFF6B6B), size: 20),
              SizedBox(width: 10),
              Text('Logout', style: TextStyle(color: Color(0xFFFF6B6B), fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  // --- Helper Methods ---

  IconData _getKYCIcon() {
    if (_userService.kycStatus == 'Rejected' && (_userService.kycRejectionReason?.toLowerCase().contains('name mismatch') ?? false)) return Icons.warning_amber;
    switch (_userService.kycStatus) {
      case 'Completed': return Icons.verified;
      case 'Pending': return Icons.pending;
      case 'Rejected': return Icons.cancel;
      default: return Icons.fact_check;
    }
  }

  String _getKYCDescription() {
    if (_userService.canRestartKYC()) return 'KYC incomplete - click to restart';
    if (_userService.kycStatus == 'Rejected' && (_userService.kycRejectionReason?.toLowerCase().contains('name mismatch') ?? false)) return 'Name mismatch - Update profile';
    switch (_userService.kycStatus) {
      case 'Completed': return 'Identity verified';
      case 'Pending': return 'Verification in progress';
      case 'Rejected': return 'Documents rejected';
      default: return 'Unlock full features';
    }
  }

  String _getWalletBalance(String walletType) {
    if (_isLoadingWallet && !unified.UnifiedWalletService.isInitialized) return '...';
    double total = 0.0; String currency = 'USDT';
    switch (walletType.toUpperCase()) {
      case 'MAIN': total = unified.UnifiedWalletService.mainUSDTBalance; if (total == 0.0) total = _mainUSDT; break;
      case 'SPOT': total = unified.UnifiedWalletService.spotUSDTBalance; if (total == 0.0) total = _spotUSDT; break;
      case 'P2P': total = unified.UnifiedWalletService.p2pUSDTBalance; if (total == 0.0) total = _p2pUSDT; break;
      case 'BOT': total = unified.UnifiedWalletService.botUSDTBalance; if (total == 0.0) total = _botUSDT; break;
      case 'INR': currency = 'INR'; total = unified.UnifiedWalletService.mainINRBalance;
        if (total == 0.0) { final val = _walletBalances['inr'] ?? _walletBalances['INR']; if (val != null) total = double.tryParse(val.toString()) ?? 0.0; } break;
    }
    return _isWalletHidden ? '*** $currency' : '${total.toStringAsFixed(2)} $currency';
  }
  
  String _getCoinBalance(String coin) {
    double total = 0.0;
    if (coin == 'INR') {
      total = unified.UnifiedWalletService.totalINRBalance;
      if (total == 0.0) total = double.tryParse((_walletBalances['inr'] ?? _walletBalances['INR'] ?? 0.0).toString()) ?? 0.0;
    } else if (coin == 'USDT') {
      total = unified.UnifiedWalletService.totalUSDTBalance;
      if (total == 0.0) total = _mainUSDT + _spotUSDT + _p2pUSDT + _botUSDT + _holdingUSDT;
    }
    return _isWalletHidden ? '*** $coin' : '${total.toStringAsFixed(2)} $coin';
  }

  Widget _buildSpotHoldingsList() {
    final spotRawAssets = _walletBalances['spot_raw'] as List<dynamic>? ?? [];
    final Map<String, double> combinedHoldings = {};
    for (final asset in spotRawAssets) {
      if (asset is Map) {
        final coin = (asset['asset'] ?? asset['coin'])?.toString().toUpperCase();
        final amount = double.tryParse((asset['available'] ?? asset['total'] ?? '0').toString()) ?? 0.0;
        if (coin != null) combinedHoldings[coin] = (combinedHoldings[coin] ?? 0.0) + amount;
      }
    }
    double totalUSDT = unified.UnifiedWalletService.totalUSDTBalance;
    if (totalUSDT == 0.0) totalUSDT = _mainUSDT + _spotUSDT + _p2pUSDT + _botUSDT + _holdingUSDT;
    if (totalUSDT > 0) combinedHoldings['USDT'] = totalUSDT;

    final coins = combinedHoldings.keys.where((c) => c != 'INR').toList()..sort();
    return Column(
      children: coins.map((coin) {
        final balance = combinedHoldings[coin] ?? 0.0;
        final formatted = _isWalletHidden ? '***' : coin == 'BTC' ? balance.toStringAsFixed(8) : balance.toStringAsFixed(4);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(coin, style: const TextStyle(color: Colors.white70, fontSize: 14)),
              Text('$formatted $coin', style: const TextStyle(color: Color(0xFF84BD00), fontSize: 14, fontWeight: FontWeight.bold)),
            ],
          ),
        );
      }).toList(),
    );
  }

  void _showNameMismatchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Name Mismatch Detected', style: TextStyle(color: Colors.white)),
        content: Text('Your KYC was rejected because the name on your documents does not match your profile name.\n\nReason: ${_userService.kycRejectionReason ?? "Unknown"}', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(onPressed: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => const UpdateProfileScreen())).then((_) => _loadUserData()); }, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF84BD00)), child: const Text('Update Profile', style: TextStyle(color: Colors.black))),
        ],
      ),
    );
  }

  void _showAboutCreddxDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('About Creddx', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text('Creddx is a leading cryptocurrency trading platform designed for both beginners and experienced traders.', style: TextStyle(color: Colors.white70)),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close', style: TextStyle(color: Color(0xFF84BD00))))],
      ),
    );
  }

  void _showLicencesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Licences', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text('Creddx is built using Flutter and various open-source libraries under their respective licences.', style: TextStyle(color: Colors.white70)),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close', style: TextStyle(color: Color(0xFF84BD00))))],
      ),
    );
  }
}
