import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/socket_service.dart';
import '../services/spot_service.dart';
import '../services/wallet_service.dart';
import 'login_screen.dart';
import 'update_profile_screen.dart';
import 'referral_hub_screen.dart';
import 'kyc_digilocker_instruction_screen.dart';
import 'withdraw_screen.dart';
import 'deposit_screen.dart';
import 'inr_deposit_screen.dart';
import 'inr_withdraw_upi_screen.dart';
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
  bool _isWalletViewSelected = true;
  bool _isWalletHidden = true;
  final UserService _userService = UserService();
  List<dynamic> _trustedDevices = [];
  bool _isLoadingDevices = true;
  
  // WebSocket subscription for wallet balance
  StreamSubscription<Map<String, dynamic>>? _balanceSubscription;
  Map<String, dynamic> _walletBalances = {};
  bool _isLoadingWallet = true;
  
  // Asset prices - will be updated dynamically
  Map<String, double> _assetPrices = {'ETH': 2450.00, 'USDT': 1.00, 'USDC': 1.00, 'BTC': 45000.00};
  Map<String, dynamic> _allWalletData = {};
  bool _isLoadingAssetPrices = true;
  
  // Conversion rates
  double _inrToUsdtRate = 52.0; // Dynamic conversion rate from API
  double _usdtToInrRate = 1.0 / 52.0; // Reverse conversion rate
  static const String _inrToUsdtApiUrl = 'http://localhost:8085/wallet/v1/inr/convert/inr-to-usdt';
  static const String _usdtToInrApiUrl = 'http://localhost:8085/wallet/v1/inr/convert/usdt-to-inr';
  
  static const String _wsBaseUrl = 'ws://65.0.196.122:9001';
  static const String _httpBaseUrl = 'http://65.0.196.122:9000';

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadTrustedDevices();
    _subscribeToBalance();
    _loadAllWalletData();
    _loadAssetPrices();
    _loadConversionRate();
    
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
  void dispose() {
    _balanceSubscription?.cancel();
    super.dispose();
  }

  void _subscribeToBalance() {
    _balanceSubscription = SocketService.balanceStream.listen((data) {
      if (data['type'] == 'balance_update' && data['assets'] != null) {
        debugPrint('UserProfileScreen: Balance update received via SocketService');
        final assets = data['assets'] as List;
        
        // Map 'asset' to 'coin' to match UserProfileScreen expectations
        final mappedAssets = assets.map((a) => {
          'coin': a['asset'],
          'available': a['available'],
          'locked': a['locked'],
        }).toList();

        if (mounted) {
          setState(() {
            // Update spot wallet specifically if that's what the update represents
            // or merge it into the existing _walletBalances.
            // For simplicity and to maintain compatibility with existing UI logic:
            _walletBalances['spot'] = {'balances': mappedAssets};
            _walletBalances['spotBalance'] = mappedAssets; // Alternative format
            
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

  // Load comprehensive wallet data from API
  Future<void> _loadAllWalletData() async {
    setState(() {
      _isLoadingWallet = true;
    });

    try {
      // Try user service first - fetches user assets from /user/v1/user
      final userResult = await UserService.getUserAssets();
      if (userResult['success'] == true && userResult['data'] != null) {
        final data = userResult['data'];
        final userData = userResult['userData'] ?? {};
        setState(() {
          _allWalletData = data;
          _walletBalances = data; // Sync with _walletBalances for UI display
          _isLoadingWallet = false;
        });
        debugPrint('Loaded user assets from /user/v1/user API: $data');
        debugPrint('Full user data: $userData');
        return;
      }

      // Fallback to wallet service if user API fails
      final walletResult = await WalletService.getAllWalletBalances();
      if (walletResult['success'] == true && walletResult['data'] != null) {
        final data = walletResult['data'];
        setState(() {
          _allWalletData = data;
          _walletBalances = data;
          _isLoadingWallet = false;
        });
        debugPrint('Loaded wallet data from API: $data');
        return;
      }

      // Fallback to spot service if wallet service fails
      final spotResult = await SpotService.getBalance();
      if (spotResult['success'] == true && spotResult['data'] != null) {
        final data = spotResult['data'];
        setState(() {
          _allWalletData = data;
          _walletBalances = data;
          _isLoadingWallet = false;
        });
        debugPrint('Loaded spot wallet data from API: $data');
        return;
      }

      // If all APIs fail, set empty data but mark loading as done
      setState(() {
        _walletBalances = {};
        _isLoadingWallet = false;
      });
    } catch (e) {
      debugPrint('Error loading wallet data: $e');
      setState(() {
        _walletBalances = {};
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

  Future<void> _loadUserData() async {
    await _userService.initUserData();
    await _userService.fetchKYCStatusFromAPI(); // Refresh KYC status
    if (mounted) {
      setState(() {});
    }
    
    // Refresh again after API data is fetched (IP address comes from login activity API)
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() {});
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh user data when screen regains focus
    _loadUserData();
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
      body: SingleChildScrollView(
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
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const UpdateProfileScreen()));
                        },
                        child: const Text(
                          'Edit',
                          style: TextStyle(color: Color(0xFF84BD00), fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text('User ID', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1C1E),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_userService.userId ?? '5a4e882d', style: const TextStyle(color: Colors.white, fontSize: 15)),
                        const Icon(Icons.copy, color: Colors.white54, size: 18),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildProfileInfoRow('Email', _userService.userEmail ?? 'Not provided'),
                  const SizedBox(height: 12),
                  _buildProfileInfoRow('Sign-Up Time', _userService.signUpTime ?? '12/11/2025 | 12:30:45'),
                  const SizedBox(height: 12),
                  _buildProfileInfoRow('Last Log-In', _userService.lastLogin ?? '11/12/2025 | 11:02:12'),
                  const SizedBox(height: 12),
                  _buildProfileInfoRow('IP Address', _userService.ipAddress ?? 'Not available'),
                  const SizedBox(height: 24),
                  _buildKYCTile(),
                  const SizedBox(height: 24),
                  _buildReferralHubTile(),
                ],
              ),
            ),
            const Divider(color: Colors.white10, height: 1),
            _buildExpandableSection(
              title: 'Assets Allocation',
              isExpanded: _isAssetsAllocationExpanded,
              onTap: () => setState(() => _isAssetsAllocationExpanded = !_isAssetsAllocationExpanded),
              content: _buildAssetsAllocationContent(),
            ),
            const Divider(color: Colors.white10, height: 1),
            _buildUSMESection(),
            const Divider(color: Colors.white10, height: 1),
            const SizedBox(height: 16),
            // Logout button at bottom
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: _buildLogoutButton(),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildKYCTile() {
    return GestureDetector(
      onTap: () async {
        if (_userService.isKYCNotStarted() || _userService.isKYCRejected()) {
          final result = await Navigator.push(
            context, 
            MaterialPageRoute(builder: (context) => const KYCDigiLockerInstructionScreen())
          );
          // KYC flow will handle status updates automatically
          if (mounted) {
            _loadUserData();
            setState(() {});
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
                  Text(
                    'KYC Verification',
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _getKYCDescription(),
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
            Column(
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
            ),
            if (_userService.isKYCNotStarted() || _userService.isKYCRejected())
              const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 14),
          ],
        ),
      ),
    );
  }

  IconData _getKYCIcon() {
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

  Widget _buildReferralHubTile() {
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => const ReferralHubScreen()));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.hub_outlined, color: Color(0xFF84BD00), size: 22),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Referral Hub',
                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 13)),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
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

  Widget _buildAssetsAllocationContent() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => setState(() => _isWalletViewSelected = true),
                child: _buildToggleButton('Wallet View', _isWalletViewSelected),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => setState(() => _isWalletViewSelected = false),
                child: _buildToggleButton('Coin View', !_isWalletViewSelected),
              ),
              const Spacer(),
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
              final items = _isWalletViewSelected
                ? ['Main', 'SPOT', 'P2P', 'Bot']
                : ['INR', 'USDT'];
              return items.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                final balance = _isWalletViewSelected
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
    if (_isLoadingWallet) return '...';

    debugPrint('Getting wallet balance for: $walletType');
    debugPrint('Current wallet balances data: $_walletBalances');

    // If no data from API, show 0.00
    if (_walletBalances.isEmpty) {
      debugPrint('No wallet balance data available from API');
      final currency = walletType == 'INR' ? 'INR' : 'USDT';
      if (_isWalletHidden) return '*** $currency';
      return '0.00 $currency';
    }

    final data = _walletBalances;
    double total = 0.0;
    String currency = 'USDT';

    // Special handling for INR wallet
    if (walletType == 'INR') {
      currency = 'INR';

      // Try flat format first (like wallet screen)
      if (data['mainBalance'] is Map) {
        final mainBalance = data['mainBalance'] as Map;
        if (mainBalance['INR'] != null) {
          total = double.tryParse(mainBalance['INR'].toString()) ?? 0.0;
          debugPrint('Found INR balance from flat format: $total');
        }
      }

      // Check for INR in main wallet balances list
      if (total == 0.0 && data['main'] != null) {
        final main = data['main'];
        if (main is Map && main['balances'] is List) {
          for (final bal in main['balances']) {
            if (bal is Map && bal['coin']?.toString().toUpperCase() == 'INR') {
              total = double.tryParse(bal['total']?.toString() ?? bal['available']?.toString() ?? '0') ?? 0.0;
              debugPrint('Found INR balance in main wallet balances: $total');
              break;
            }
          }
        }
      }

      // Direct keys fallback
      if (total == 0.0 && data['inr'] != null) {
        total = double.tryParse(data['inr'].toString()) ?? 0.0;
      } else if (total == 0.0 && data['inr_total'] != null) {
        total = double.tryParse(data['inr_total'].toString()) ?? 0.0;
      } else if (total == 0.0 && data['inr_available'] != null) {
        total = double.tryParse(data['inr_available'].toString()) ?? 0.0;
      }

      // Nested data structure
      if (total == 0.0 && data['data'] != null) {
        final nestedData = data['data'];
        if (nestedData is Map) {
          total = double.tryParse(nestedData['inr']?.toString() ?? nestedData['inr_total']?.toString() ?? nestedData['inr_available']?.toString() ?? '0') ?? 0.0;
        }
      }
    } else {
      // Handle other wallets (Main, SPOT, P2P, Bot)
      final typeKey = walletType.toLowerCase();

      // Map wallet type to flat format field names (like wallet screen)
      final flatFieldMap = {
        'main': 'mainBalance',
        'spot': 'spotBalance',
        'p2p': 'p2pBalance',
        'bot': 'botBalance',
      };

      // Try flat format first (like wallet screen does)
      final fieldName = flatFieldMap[typeKey];
      if (fieldName != null && data[fieldName] != null) {
        final walletData = data[fieldName];
        debugPrint('Found flat format wallet data for $typeKey: $walletData');

        if (walletData is Map) {
          // Format: {USDT: Y, INR: X}
          if (walletData['USDT'] != null) {
            total = double.tryParse(walletData['USDT'].toString()) ?? 0.0;
            debugPrint('Found USDT in flat format for $typeKey: $total');
          }
        } else if (walletData is num) {
          // Format: spotBalance: 0 (direct number)
          total = walletData.toDouble();
          debugPrint('Found USDT as direct number for $typeKey: $total');
        }
      }

      // Try nested format (balances array)
      if (total == 0.0 && data[typeKey] != null) {
        final wallet = data[typeKey];
        debugPrint('Found nested wallet data for $typeKey: $wallet');

        if (wallet is Map) {
          final balances = wallet['balances'];
          if (balances is List) {
            debugPrint('Found balances list: $balances');
            for (final bal in balances) {
              if (bal is Map && (bal['coin']?.toString().toUpperCase() == 'USDT' || bal['asset']?.toString().toUpperCase() == 'USDT')) {
                final available = double.tryParse(bal['available']?.toString() ?? '0') ?? 0.0;
                final locked = double.tryParse(bal['locked']?.toString() ?? '0') ?? 0.0;
                total = double.tryParse(bal['total']?.toString() ?? '0') ?? (available + locked);
                debugPrint('Found USDT balance in balances array: available=$available, locked=$locked, total=$total');
                break;
              }
            }
          } else if (wallet['usdt_total'] != null) {
            total = double.tryParse(wallet['usdt_total'].toString()) ?? 0.0;
          } else if (wallet['total'] != null) {
            total = double.tryParse(wallet['total'].toString()) ?? 0.0;
          }
        } else if (wallet is num) {
          total = wallet.toDouble();
        }
      }

      // Check nested data structure fallback
      if (total == 0.0 && data['data'] != null) {
        final nestedData = data['data'];
        if (nestedData is Map && nestedData[typeKey] != null) {
          final wallet = nestedData[typeKey];
          if (wallet is Map && wallet['balances'] is List) {
            for (final bal in wallet['balances']) {
              if (bal is Map && (bal['coin']?.toString().toUpperCase() == 'USDT' || bal['asset']?.toString().toUpperCase() == 'USDT')) {
                final available = double.tryParse(bal['available']?.toString() ?? '0') ?? 0.0;
                final locked = double.tryParse(bal['locked']?.toString() ?? '0') ?? 0.0;
                total = double.tryParse(bal['total']?.toString() ?? '0') ?? (available + locked);
                break;
              }
            }
          }
        }
      }
    }

    debugPrint('Final calculated balance for $walletType: $total $currency');
    if (_isWalletHidden) return '*** $currency';
    return '${total.toStringAsFixed(2)} $currency';
  }
  
  String _getCoinBalance(String coin) {
    if (_isLoadingWallet) return '...';
    
    final coinKey = coin.toLowerCase();
    final data = _walletBalances;
    double total = 0.0;
    
    // If no data from API, show 0.00 (no mock data)
    if (_walletBalances.isEmpty) {
      debugPrint('No coin balance data available from API');
      if (_isWalletHidden) return '*** $coin';
      return '0.00 $coin';
    }
    
    // Special handling for INR
    if (coin == 'INR') {
      // First try flat format: mainBalance.INR
      if (data['mainBalance'] is Map && data['mainBalance']['INR'] != null) {
        total = double.tryParse(data['mainBalance']['INR'].toString()) ?? 0.0;
        debugPrint('Found INR in mainBalance flat format: $total');
      }

      // Direct keys fallback
      if (total == 0.0 && data['inr'] != null) {
        total = double.tryParse(data['inr'].toString()) ?? 0.0;
      } else if (total == 0.0 && data['inr_available'] != null) {
        total = double.tryParse(data['inr_available'].toString()) ?? 0.0;
      } else if (total == 0.0 && data['inr_total'] != null) {
        total = double.tryParse(data['inr_total'].toString()) ?? 0.0;
      }

      // Check nested data structure
      if (total == 0.0 && data['data'] != null) {
        final nestedData = data['data'];
        if (nestedData is Map) {
          total = double.tryParse(nestedData['inr']?.toString() ?? '0') ?? 0.0;
          if (total == 0.0) {
            total = double.tryParse(nestedData['inr_available']?.toString() ?? '0') ?? 0.0;
          }
        }
      }
    } else {
      // Sum balance from all wallets for this coin (USDT, BTC)
      // First try flat format (like wallet screen): mainBalance, spotBalance, p2pBalance, botBalance
      final flatFieldMap = {
        'main': 'mainBalance',
        'spot': 'spotBalance',
        'p2p': 'p2pBalance',
        'bot': 'botBalance',
      };

      for (String walletType in flatFieldMap.keys) {
        final fieldName = flatFieldMap[walletType]!;
        if (data[fieldName] != null) {
          final walletData = data[fieldName];
          if (walletData is Map) {
            // Format: {USDT: Y, INR: X}
            if (walletData[coin] != null) {
              final value = double.tryParse(walletData[coin].toString()) ?? 0.0;
              total += value;
              debugPrint('Found $coin in flat format $fieldName: $value');
            }
          } else if (walletData is num) {
            // Format: spotBalance: 0 (direct number) - assume USDT
            if (coin == 'USDT') {
              final value = walletData.toDouble();
              total += value;
              debugPrint('Found USDT as direct number in $fieldName: $value');
            }
          }
        }
      }

      // Try nested format if flat format didn't find anything
      if (total == 0.0) {
        final walletTypes = ['main', 'spot', 'p2p', 'bot'];
        for (String walletType in walletTypes) {
          if (data[walletType] != null) {
            final wallet = data[walletType];
            if (wallet is Map) {
              final balances = wallet['balances'];
              if (balances is List) {
                for (final bal in balances) {
                  if (bal is Map && bal['coin']?.toString().toUpperCase() == coin) {
                    final available = double.tryParse(bal['available']?.toString() ?? '0') ?? 0.0;
                    final locked = double.tryParse(bal['locked']?.toString() ?? '0') ?? 0.0;
                    total += available + locked;
                    break;
                  }
                }
              } else if (wallet['${coinKey}_total'] != null) {
                total += double.tryParse(wallet['${coinKey}_total'].toString()) ?? 0.0;
              } else if (wallet[coinKey] != null) {
                total += double.tryParse(wallet[coinKey].toString()) ?? 0.0;
              }
            }
          }
        }
      }

      // Check nested data structure
      if (total == 0.0 && data['data'] != null) {
        final nestedData = data['data'];
        if (nestedData is Map) {
          for (String walletType in ['main', 'spot', 'p2p', 'bot']) {
            if (nestedData[walletType] != null) {
              final wallet = nestedData[walletType];
              if (wallet is Map && wallet['balances'] is List) {
                for (final bal in wallet['balances']) {
                  if (bal is Map && bal['coin']?.toString().toUpperCase() == coin) {
                    final available = double.tryParse(bal['available']?.toString() ?? '0') ?? 0.0;
                    final locked = double.tryParse(bal['locked']?.toString() ?? '0') ?? 0.0;
                    total += available + locked;
                    break;
                  }
                }
              }
            }
          }
        }
      }

      // Also check direct coin keys in data
      if (total == 0.0 && data[coinKey] != null) {
        total = double.tryParse(data[coinKey].toString()) ?? 0.0;
      }
      if (total == 0.0 && data['${coinKey}_total'] != null) {
        total = double.tryParse(data['${coinKey}_total'].toString()) ?? 0.0;
      }
    }
    
    if (_isWalletHidden) return '*** $coin';
    
    // Format based on coin type
    if (coin == 'INR') {
      return '${total.toStringAsFixed(2)} $coin';
    } else if (coin == 'BTC') {
      return '${total.toStringAsFixed(8)} $coin';
    } else {
      return '${total.toStringAsFixed(6)} $coin';
    }
  }
  
  Widget _buildWalletRow(String walletType, String balance) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          // Wallet Icon
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _getWalletColor(walletType).withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              _getWalletIcon(walletType),
              color: _getWalletColor(walletType),
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$walletType Holding',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                ),
                if (!_isWalletHidden) ...[
                  const SizedBox(height: 2),
                  Text(
                    _getWalletSubtitle(walletType),
                    style: const TextStyle(color: Colors.white38, fontSize: 10),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(
            width: 80,
            child: Text(
              balance,
              style: const TextStyle(
                color: Colors.white, 
                fontSize: 12, 
                fontWeight: FontWeight.w500
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 50,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () {
                    if (walletType == 'INR') {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const InrDepositScreen()));
                    } else {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const DepositScreen()));
                    }
                  },
                  child: Container(
                    width: 50,
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    decoration: BoxDecoration(
                      color: walletType == 'INR' ? const Color(0xFF84BD00).withOpacity(0.2) : const Color(0xFF2C2C2E),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Deposit',
                      style: TextStyle(
                        color: walletType == 'INR' ? const Color(0xFF84BD00) : Colors.white70, 
                        fontSize: 9, 
                        fontWeight: FontWeight.w500
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                GestureDetector(
                  onTap: () {
                    if (walletType == 'INR') {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const InrWithdrawUpiScreen()));
                    } else {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const WithdrawScreen()));
                    }
                  },
                  child: Container(
                    width: 50,
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    decoration: BoxDecoration(
                      color: walletType == 'INR' ? const Color(0xFF84BD00) : const Color(0xFF84BD00),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Withdraw',
                      style: TextStyle(
                        color: Colors.black, 
                        fontSize: 9, 
                        fontWeight: FontWeight.w600
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods for wallet styling
  IconData _getWalletIcon(String walletType) {
    switch (walletType.toUpperCase()) {
      case 'INR':
        return Icons.currency_rupee;
      case 'USDT':
      case 'USDC':
        return Icons.attach_money;
      case 'BTC':
        return Icons.currency_bitcoin;
      case 'ETH':
        return Icons.currency_exchange;
      case 'SPOT':
        return Icons.show_chart;
      case 'P2P':
        return Icons.swap_horiz;
      case 'MAIN':
        return Icons.account_balance;
      default:
        return Icons.wallet;
    }
  }
  
  Color _getWalletColor(String walletType) {
    switch (walletType.toUpperCase()) {
      case 'INR':
        return const Color(0xFF84BD00);
      case 'USDT':
        return const Color(0xFF26A17B);
      case 'USDC':
        return const Color(0xFF2775CA);
      case 'BTC':
        return const Color(0xFFF7931A);
      case 'ETH':
        return const Color(0xFF627EEA);
      case 'SPOT':
        return const Color(0xFF9333EA);
      case 'P2P':
        return const Color(0xFF10B981);
      case 'MAIN':
        return const Color(0xFF3B82F6);
      default:
        return Colors.grey;
    }
  }
  
  String _getWalletSubtitle(String walletType) {
    switch (walletType.toUpperCase()) {
      case 'INR':
        return 'Indian Rupee';
      case 'USDT':
        return 'Tether USD';
      case 'USDC':
        return 'USD Coin';
      case 'BTC':
        return 'Bitcoin';
      case 'ETH':
        return 'Ethereum';
      case 'SPOT':
        return 'Spot Trading';
      case 'P2P':
        return 'Peer-to-Peer';
      case 'MAIN':
        return 'Main Wallet';
      default:
        return 'Digital Asset';
    }
  }

  Widget _buildToggleButton(String text, bool isSelected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF84BD00) : const Color(0xFF2C2C2E),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(color: isSelected ? Colors.black : Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildAssetRow(String symbol, String label, String balance, String price) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(symbol, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('USDT Price: $price', style: const TextStyle(color: Colors.white38, fontSize: 12)),
            ],
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(label, style: const TextStyle(color: Colors.white38, fontSize: 12)),
              const SizedBox(height: 4),
              Text(balance, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        Column(
          children: [
            GestureDetector(
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const WithdrawScreen()));
              },
              child: _buildAssetActionButton('Withdraw', const Color(0xFF84BD00)),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const DepositScreen()));
              },
              child: _buildAssetActionButton('Deposit', Colors.white10),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAssetActionButton(String text, Color color) {
    return Container(
      width: 80,
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: TextStyle(color: color == const Color(0xFF84BD00) ? Colors.black : Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildTrustedDevicesContent() {
    if (_isLoadingDevices) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: const Center(
          child: BitcoinLoadingIndicator(size: 40),
        ),
      );
    }

    if (_trustedDevices.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.devices_outlined,
                size: 48,
                color: Colors.grey[600],
              ),
              const SizedBox(height: 12),
              Text(
                'No trusted devices found',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your trusted devices will appear here',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: _trustedDevices.map((device) {
          // Extract data from API response
          final trusted = device['isTrusted'] == true || device['trusted'] == true ? 'YES' : 'NO';
          final ip = device['ipAddress'] ?? device['ip'] ?? 'Unknown IP';
          final date = device['lastLoginAt'] ?? device['createdAt'] ?? 'Unknown Date';
          final deviceName = device['deviceName'] ?? device['deviceType'] ?? 'Unknown Device';
          final deviceId = device['id']?.toString() ?? device['_id']?.toString() ?? '';
          
          return Column(
            children: [
              _buildDeviceItem(trusted, ip, date, deviceName, deviceId),
              if (device != _trustedDevices.last) 
                const Divider(color: Colors.white10, height: 32),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDeviceItem(String trusted, String ip, String date, String device, String deviceId) {
    return Row(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Trusted device', style: TextStyle(color: Colors.white38, fontSize: 11)),
              const SizedBox(height: 4),
              Text(trusted, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              const Text('Recent Activity', style: TextStyle(color: Colors.white38, fontSize: 11)),
              const SizedBox(height: 4),
              Text(date, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Login IP', style: TextStyle(color: Colors.white38, fontSize: 11)),
              const SizedBox(height: 4),
              Text(ip, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              const Text('Recent Activity Device', style: TextStyle(color: Colors.white38, fontSize: 11)),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(device, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                  if (deviceId.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Icon(
                      Icons.verified_user_outlined,
                      color: trusted == 'YES' ? const Color(0xFF84BD00) : Colors.grey[600],
                      size: 16,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUSMESection() {
    return _buildExpandableSection(
      title: 'Security & Devices',
      isExpanded: true,
      onTap: () {},
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          

          

          const SizedBox(height: 12),
          
          // Trusted Devices Content
          if (_isLoadingDevices)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: CircularProgressIndicator(color: Color(0xFF84BD00)),
              ),
            )
          else if (_trustedDevices.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.devices_outlined,
                      size: 32,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No trusted devices found',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Column(
              children: _trustedDevices.map((device) {
                final trusted = device['isTrusted'] == true || device['trusted'] == true ? 'YES' : 'NO';
                final ip = device['ipAddress'] ?? device['ip'] ?? 'Unknown IP';
                final date = device['lastLoginAt'] ?? device['createdAt'] ?? 'Unknown Date';
                final deviceName = device['deviceName'] ?? device['deviceType'] ?? 'Unknown Device';
                final deviceId = device['id']?.toString() ?? device['_id']?.toString() ?? '';
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C1E),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: trusted == 'YES' ? const Color(0xFF84BD00) : const Color(0xFF2C2C2E),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Device: $deviceName',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Status: $trusted',
                                  style: TextStyle(
                                    color: trusted == 'YES' ? const Color(0xFF84BD00) : Colors.grey[400],
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Last Activity: $date',
                                  style: const TextStyle(
                                    color: Color(0xFF8E8E93),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.verified_user_outlined,
                            color: trusted == 'YES' ? const Color(0xFF84BD00) : Colors.grey[600],
                            size: 20,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            color: const Color(0xFF8E8E93),
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'IP Address: $ip',
                            style: const TextStyle(
                              color: Color(0xFF8E8E93),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          
          const SizedBox(height: 32),
          
          // IP Address Summary
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF2C2C2E)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.network_check_outlined,
                      color: const Color(0xFF84BD00),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'IP Address Summary',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Current Session IP',
                            style: TextStyle(color: Color(0xFF8E8E93), fontSize: 12),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _userService.ipAddress ?? 'Loading...',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF84BD00).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Secure',
                        style: TextStyle(
                          color: const Color(0xFF84BD00),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPortfolioSummary() {
    double totalPortfolioValue = 0.0;
    
    try {
      // Calculate total portfolio value in USDT
      if (_isWalletViewSelected) {
        // Wallet view: sum all wallet balances
        final wallets = ['Main', 'SPOT', 'P2P', 'INR'];
        for (String wallet in wallets) {
          try {
            final balanceStr = _getWalletBalance(wallet);
            final balance = _parseBalanceValue(balanceStr, wallet == 'INR' ? 'INR' : 'USDT');
            if (wallet == 'INR') {
              // Convert INR to USDT using current conversion rate
              totalPortfolioValue += balance * _inrToUsdtRate;
            } else {
              totalPortfolioValue += balance;
            }
          } catch (e) {
            debugPrint('Error calculating balance for wallet $wallet: $e');
            // Continue with other wallets even if one fails
          }
        }
      } else {
        // Coin view: sum all coin values
        final coins = ['INR', 'USDT', 'BTC', 'ETH'];
        for (String coin in coins) {
          try {
            if (coin == 'USDT') {
              final balanceStr = _getCoinBalance(coin);
              final balance = _parseBalanceValue(balanceStr, 'USDT');
              totalPortfolioValue += balance;
            } else if (coin == 'BTC' || coin == 'ETH') {
              final balanceStr = _getCoinBalance(coin);
              final balance = _parseBalanceValue(balanceStr, coin);
              final price = _assetPrices[coin] ?? 0.0;
              totalPortfolioValue += balance * price;
            } else if (coin == 'INR') {
              final balanceStr = _getCoinBalance(coin);
              final balance = _parseBalanceValue(balanceStr, 'INR');
              totalPortfolioValue += balance * _inrToUsdtRate; // Convert INR to USDT
            }
          } catch (e) {
            debugPrint('Error calculating value for coin $coin: $e');
            // Continue with other coins even if one fails
          }
        }
      }
    } catch (e) {
      debugPrint('Error in portfolio calculation: $e');
      // Return 0 if everything fails
      totalPortfolioValue = 0.0;
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF84BD00).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.account_balance_wallet_outlined,
                    color: const Color(0xFF84BD00),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Total Portfolio Value',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: _loadConversionRate,
                child: Icon(
                  Icons.refresh,
                  color: Colors.white54,
                  size: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _isWalletHidden 
                ? '*** USDT' 
                : '\$${totalPortfolioValue.toStringAsFixed(2)} USDT',
            style: TextStyle(
              color: const Color(0xFF84BD00),
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (!_isWalletHidden) ...[
            const SizedBox(height: 8),
            Text(
              'Equivalent to all your assets combined',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'INR to USDT: 1 INR = $_inrToUsdtRate USDT',
              style: TextStyle(
                color: const Color(0xFF84BD00),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              'USDT to INR: 1 USDT = $_usdtToInrRate INR',
              style: TextStyle(
                color: const Color(0xFF84BD00),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLogoutButton() {
    return GestureDetector(
      onTap: () => _showLogoutConfirmDialog(),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        decoration: BoxDecoration(
          color: const Color(0xFFFF3B30),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.logout,
              color: Colors.white,
              size: 20,
            ),
            SizedBox(width: 8),
            Text(
              'Logout',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutConfirmDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1C1C1E),
          title: const Text(
            'Logout',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'Are you sure you want to logout?',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _handleLogout();
              },
              child: const Text(
                'Logout',
                style: TextStyle(color: Color(0xFFFF3B30)),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleLogout() async {
    final result = await AuthService.logout();
    if (result['success'] == true) {
      // Navigate to login screen and clear all previous routes
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => LoginScreen()),
          (route) => false,
        );
      }
    } else {
      // Show error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Logout failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
