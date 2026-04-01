import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';
import 'update_profile_screen.dart';
import 'referral_hub_screen.dart';
import 'kyc_document_screen.dart';
import 'withdraw_screen.dart';
import 'deposit_screen.dart';
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
  
  // WebSocket for wallet balance
  WebSocketChannel? _walletWsChannel;
  Map<String, dynamic> _walletBalances = {};
  bool _isLoadingWallet = true;
  String? _walletError;
  Timer? _loadingTimeout;
  
  // Asset prices
  Map<String, double> _assetPrices = {'ETH': 2450.00, 'USDT': 1.00, 'USDC': 1.00};
  
  static const String _wsBaseUrl = 'ws://13.235.89.109:9001';
  static const String _httpBaseUrl = 'http://13.235.89.109:9000';

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadTrustedDevices();
    _connectWalletWebSocket();
  }
  
  @override
  void dispose() {
    _walletWsChannel?.sink.close();
    _loadingTimeout?.cancel();
    super.dispose();
  }
  
  // Fallback: Fetch balance via REST API
  Future<void> _fetchBalanceViaHttp() async {
    try {
      final token = await AuthService.getToken();
      final userId = await _getUserId();
      
      final response = await http.get(
        Uri.parse('$_httpBaseUrl/balance/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));
      
      debugPrint('HTTP Balance Response: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          setState(() {
            _walletBalances = data['data'];
            _isLoadingWallet = false;
          });
          return;
        }
      }
      
      // If HTTP fails, show 0 balances
      setState(() {
        _walletBalances = {};
        _isLoadingWallet = false;
      });
    } catch (e) {
      debugPrint('HTTP balance fetch error: $e');
      setState(() {
        _walletBalances = {};
        _isLoadingWallet = false;
      });
    }
  }
  
  Future<String> _getUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? userId = prefs.getString('user_id');
      if (userId != null) return userId;
      int? userIdInt = prefs.getInt('user_id');
      if (userIdInt != null) return userIdInt.toString();
      return '1';
    } catch (e) {
      return '1';
    }
  }
  
  void _connectWalletWebSocket() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        setState(() {
          _walletError = 'Authentication required';
          _isLoadingWallet = false;
        });
        return;
      }
      
      // Add timeout to stop loading if WebSocket doesn't respond
      _loadingTimeout = Timer(const Duration(seconds: 5), () {
        if (mounted && _isLoadingWallet) {
          debugPrint('WebSocket timeout, trying HTTP fallback...');
          _fetchBalanceViaHttp();
        }
      });
      
      _walletWsChannel = WebSocketChannel.connect(
        Uri.parse('ws://13.235.89.109:9001/ws'),
        protocols: ['websocket'],
      );
      
      _walletWsChannel!.stream.listen(
        _handleWalletWebSocketMessage,
        onError: (error) {
          debugPrint('Wallet WebSocket error: $error');
          if (mounted) {
            setState(() {
              _isLoadingWallet = false;
              _walletBalances = {};
            });
          }
        },
        onDone: () {
          debugPrint('Wallet WebSocket disconnected, reconnecting...');
          Future.delayed(const Duration(seconds: 5), () {
            if (mounted) _connectWalletWebSocket();
          });
        },
      );
      
      // Authenticate and subscribe to balance updates
      _sendWalletWsMessage({
        'type': 'auth',
        'token': token,
      });
      
      _sendWalletWsMessage({
        'type': 'subscribe',
        'channel': 'balance',
      });
    } catch (e) {
      debugPrint('Wallet WebSocket connection error: $e');
      setState(() {
        _walletError = null;
        _isLoadingWallet = false;
        _walletBalances = {};
      });
    }
  }
  
  void _handleWalletWebSocketMessage(dynamic message) {
    try {
      final data = json.decode(message);
      debugPrint('Wallet WebSocket message: $data');
      
      // Handle various response formats - only cancel timeout when we get actual data
      if (data['type'] == 'balance_update' || 
          data['channel'] == 'balance' || 
          data['balances'] != null ||
          data['spot'] != null ||
          data['main'] != null ||
          data['p2p'] != null ||
          data['bot'] != null ||
          data['data'] != null) {
        // Cancel timeout only when we get actual balance data
        _loadingTimeout?.cancel();
        setState(() {
          _walletBalances = data['data'] ?? data;
          _isLoadingWallet = false;
        });
      } else if (data['type'] == 'auth_ok' || data['success'] == true) {
        debugPrint('WebSocket authenticated, requesting balances...');
        _sendWalletWsMessage({'type': 'get_balances'});
      }
    } catch (e) {
      debugPrint('Error parsing WebSocket message: $e');
    }
  }
  
  void _sendWalletWsMessage(Map<String, dynamic> message) {
    if (_walletWsChannel != null) {
      _walletWsChannel!.sink.add(json.encode(message));
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

  Future<void> _loadUserData() async {
    await _userService.initUserData();
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
            MaterialPageRoute(builder: (context) => const KYCDocumentScreen())
          );
          // KYC flow will handle status updates automatically
          if (result != null) {
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
      case 'Verified':
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
      case 'Verified':
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
    final walletTypes = ['Main', 'SPOT', 'P2P', 'Bot'];
    
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
                child: Text('Total Price', style: TextStyle(color: Colors.white54, fontSize: 11)),
              ),
              const SizedBox(width: 4),
              const SizedBox(
                width: 50,
                child: Text('Actions', style: TextStyle(color: Colors.white54, fontSize: 11), textAlign: TextAlign.right),
              ),
            ],
          ),
          const Divider(color: Colors.white10, height: 24),
          if (_isLoadingWallet)
            const Center(
              child: SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(color: Color(0xFF84BD00), strokeWidth: 2),
              ),
            )
          else ...[
            ...(_isWalletViewSelected 
              ? ['Main', 'SPOT', 'P2P', 'Bot']
              : ['INR', 'USDT']
            ).asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final balance = _isWalletViewSelected 
                ? _getWalletBalance(item)
                : _getCoinBalance(item);
              final isLast = index == (_isWalletViewSelected ? 4 : 2) - 1;
              
              return Column(
                children: [
                  _buildWalletRow(item, balance),
                  if (!isLast) const Divider(color: Colors.white10, height: 16),
                ],
              );
            }).toList(),
          ],
        ],
      ),
    );
  }
  
  String _getWalletBalance(String walletType) {
    if (_isLoadingWallet) return '...';
    
    // Map wallet type to API response keys
    final typeKey = walletType.toLowerCase();
    final data = _walletBalances;
    
    double total = 0.0;
    
    // Check different possible data structures
    if (data[typeKey] != null) {
      final wallet = data[typeKey];
      if (wallet is Map) {
        // Try to get USDT balance from this wallet
        final balances = wallet['balances'];
        if (balances is List) {
          for (final bal in balances) {
            if (bal is Map && (bal['coin']?.toString().toUpperCase() == 'USDT' || bal['asset']?.toString().toUpperCase() == 'USDT')) {
              final available = double.tryParse(bal['available']?.toString() ?? '0') ?? 0.0;
              final locked = double.tryParse(bal['locked']?.toString() ?? '0') ?? 0.0;
              total = available + locked;
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
    
    // Also check nested data structure
    if (total == 0.0 && data['data'] != null) {
      final nestedData = data['data'];
      if (nestedData is Map && nestedData[typeKey] != null) {
        final wallet = nestedData[typeKey];
        if (wallet is Map) {
          if (wallet['balances'] is List) {
            for (final bal in wallet['balances']) {
              if (bal is Map && (bal['coin']?.toString().toUpperCase() == 'USDT' || bal['asset']?.toString().toUpperCase() == 'USDT')) {
                final available = double.tryParse(bal['available']?.toString() ?? '0') ?? 0.0;
                final locked = double.tryParse(bal['locked']?.toString() ?? '0') ?? 0.0;
                total = available + locked;
                break;
              }
            }
          }
        }
      }
    }
    
    if (_isWalletHidden) return '*** USDT';
    return '${total.toStringAsFixed(6)} USDT';
  }
  
  String _getCoinBalance(String coin) {
    if (_isLoadingWallet) return '...';
    
    final coinKey = coin.toLowerCase();
    final data = _walletBalances;
    double total = 0.0;
    
    // Sum balance from all wallets for this coin
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
    
    // Check nested data structure
    if (total == 0.0 && data['data'] != null) {
      final nestedData = data['data'];
      if (nestedData is Map) {
        for (String walletType in walletTypes) {
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
    
    if (_isWalletHidden) return '*** $coin';
    return '${total.toStringAsFixed(6)} $coin';
  }
  
  Widget _buildWalletRow(String walletType, String balance) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text('$walletType Holding', 
              style: const TextStyle(color: Colors.white, fontSize: 11),
            ),
          ),
          SizedBox(
            width: 80,
            child: Text(balance, 
              style: const TextStyle(color: Colors.white, fontSize: 10),
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
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const DepositScreen()));
                  },
                  child: Container(
                    width: 50,
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C2C2E),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'Deposit',
                      style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                GestureDetector(
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const WithdrawScreen()));
                  },
                  child: Container(
                    width: 50,
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF84BD00),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'Withdraw',
                      style: TextStyle(color: Colors.black, fontSize: 8, fontWeight: FontWeight.w600),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Trusted Device', style: TextStyle(color: Colors.white38, fontSize: 11)),
              const SizedBox(height: 4),
              Text(trusted, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              const Text('Recent Activity', style: TextStyle(color: Colors.white38, fontSize: 11)),
              const SizedBox(height: 4),
              Text(date, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
            ],
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
          

          
          // Trusted Devices Subsection
          const Text(
            'Trusted Devices',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
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
