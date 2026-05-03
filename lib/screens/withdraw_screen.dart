import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'qr_scanner_screen.dart';
import 'otp_verification_screen.dart';
import 'dart:async';
import '../services/socket_service.dart';
import '../services/wallet_service.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../services/notification_service.dart';
import '../services/unified_wallet_service.dart' as unified;
import '../services/auto_refresh_service.dart';
import '../widgets/bitcoin_loading_indicator.dart';
import '../utils/coin_icon_mapper.dart';
import 'user_profile_screen.dart';
import '../utils/kyc_unlock_mixin.dart';

class WithdrawScreen extends StatefulWidget {
  const WithdrawScreen({super.key});

  @override
  State<WithdrawScreen> createState() => _WithdrawScreenState();
}

class _WithdrawScreenState extends State<WithdrawScreen> with KYCUnlockMixin {
  final _addressController = TextEditingController();
  final _amountController = TextEditingController();
  String _selectedCoin = 'BTC';
  String _selectedNetwork = 'Bitcoin Network';
  List<Coin> _coins = [];
  List<Network> _networks = [];
  bool _isLoading = true;
  bool _isFetchingBalance = false;
  bool _isFetchingFees = false;
  double _availableBalance = 0.0;
  double _withdrawalFees = 0.0;
  String? _errorMessage;
  List<dynamic> _recentTransactions = [];
  bool _isLoadingTransactions = false;
  StreamSubscription? _balanceSubscription;
  
  final UserService _userService = UserService();
  
  @override
  void initState() {
    super.initState();
    _fetchData();
    _subscribeToBalanceUpdates();
    _userService.fetchProfileDataFromAPI(); // Refresh KYC status from /auth/me
  }

  void _subscribeToBalanceUpdates() {
    _balanceSubscription = SocketService.balanceStream.listen((data) {
      if (mounted && data['type'] == 'balance_update') {
        final payload = data['data'] ?? data;
        
        // Spot balance updates
        if (payload['wallet_type'] == 'spot' || payload['usdt_available'] != null) {
          final usdtAvailable = double.tryParse(payload['usdt_available']?.toString() ?? 
                               payload['available']?.toString() ?? '0') ?? _availableBalance;
          
          setState(() {
            _availableBalance = usdtAvailable;
          });
        }
      }
    });
  }
  
  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
    });
    
    // Fetch coins with their networks from single API
    final coinsData = await WalletService.getAllCoins();
    
    if (mounted) {
      setState(() {
        // Filter to show only USDT coin
        _coins = coinsData
            .map((data) => Coin.fromJson(data))
            .where((coin) => coin.symbol == 'USDT')
            .toList();

        if (_coins.isNotEmpty) {
          _selectedCoin = _coins.first.symbol;
        }
        
        _isLoading = false;
      });
      
      if (_coins.isNotEmpty) {
        await _updateNetworksForCoin(_coins.first);
      }
      _fetchAvailableBalance();
    }
  }
  
  Future<void> _updateNetworksForCoin(Coin coin) async {
    setState(() {
      // Use networks directly from the coin object (already parsed from API)
      _networks = coin.networks
          .where((n) => n.isActive)
          .toList();

      debugPrint('Networks loaded from coin: ${_networks.length} found');
      for (var n in _networks) {
        debugPrint('Network: ${n.name} (${n.type}) - Active: ${n.isActive}, Fee: ${n.fee}');
      }

      if (_networks.isNotEmpty) {
        _selectedNetwork = _networks.first.name;
      } else {
        _selectedNetwork = '';
      }
    });
  }
  
  void _onCoinChanged(String coinSymbol) async {
    setState(() {
      _selectedCoin = coinSymbol;
    });
    final selectedCoin = _coins.firstWhere((coin) => coin.symbol == coinSymbol);
    await _updateNetworksForCoin(selectedCoin);
    _fetchAvailableBalance();
  }
  
  void _onNetworkChanged(String networkName) {
    setState(() {
      _selectedNetwork = networkName;
    });
    _fetchAvailableBalance();
    _fetchWithdrawalFees();
  }
  
  Future<void> _fetchAvailableBalance() async {
    setState(() {
      _isFetchingBalance = true;
      _errorMessage = null;
    });

    // Use getAllWalletBalances to get mainBalance.USDT
    final result = await WalletService.getAllWalletBalances();
    debugPrint('Withdraw Screen - API Result: $result');

    if (mounted) {
      setState(() {
        if (result['success'] == true && result['data'] != null) {
          final data = result['data'];
          debugPrint('Withdraw Screen - Data: $data');

          // Extract USDT from mainBalance
          if (data is Map && data['mainBalance'] is Map) {
            final mainBalance = data['mainBalance'] as Map;
            final usdtBalance = mainBalance['USDT'];
            if (usdtBalance != null) {
              _availableBalance = double.tryParse(usdtBalance.toString()) ?? 0.0;
            }
          }
          debugPrint('Withdraw Screen - Parsed USDT Balance: $_availableBalance');
        } else {
          debugPrint('Withdraw Screen - API failed: ${result['error']}');
          _errorMessage = result['error']?.toString();
        }
        _isFetchingBalance = false;
      });
    }
  }
  
  Future<void> _fetchFallbackBalance() async {
    try {
      final result = await WalletService.getUSDTBalanceFromAllWallets();
      if (result['success'] == true && result['data'] != null) {
        final mainBalance = result['data']['main'];
        if (mainBalance != null) {
          final fallbackBalance = double.tryParse(mainBalance['available']?.toString() ?? '0.0') ?? 0.0;
          if (fallbackBalance > 0 && mounted) {
            setState(() {
              _availableBalance = fallbackBalance;
            });
            debugPrint('Withdraw Screen - Fallback Balance: $_availableBalance');
          }
        }
      }
    } catch (e) {
      debugPrint('Withdraw Screen - Fallback error: $e');
    }
  }

  Future<void> _fetchWithdrawalFees() async {
    if (_amountController.text.isEmpty) return;
    
    setState(() {
      _isFetchingFees = true;
    });
    
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    final result = await WalletService.getWithdrawalFees(
      coin: _selectedCoin,
      network: _selectedNetwork,
      amount: amount,
    );
    
    if (mounted) {
      setState(() {
        if (result != null) {
          _withdrawalFees = double.tryParse(result['fee']?.toString() ?? '0.0') ?? 0.0;
        }
        _isFetchingFees = false;
      });
    }
  }
  
  void _onAmountChanged(String value) {
    if (value.isNotEmpty) {
      _fetchWithdrawalFees();
    } else {
      setState(() {
        _withdrawalFees = 0.0;
      });
    }
  }
  
  void _setMaxAmount() {
    if (_availableBalance > 0) {
      _amountController.text = _availableBalance.toStringAsFixed(2);
      _fetchWithdrawalFees();
    }
  }

  // Check if KYC is completed
  bool _isKYCCompleted() {
    return isKYCCompleted(); // Now available from KYCUnlockMixin
  }

  // Check if profile is complete
  bool _isProfileComplete() {
    return _userService.hasEmail() && 
           _userService.userPhone != null && 
           _userService.userPhone!.isNotEmpty;
  }

  // Show KYC verification required dialog
  void _showKYCRequiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: const Text(
            'KYC Verification Required',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'You need to complete KYC verification to withdraw funds. Please complete your KYC process first.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Later', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const UserProfileScreen(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF84BD00)),
              child: const Text('Complete KYC', style: TextStyle(color: Colors.black)),
            ),
          ],
        );
      },
    );
  }

  // Show profile completion required dialog
  void _showProfileRequiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: const Text(
            'Profile Completion Required',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'Please complete your profile information (email and phone number) to withdraw funds.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Later', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.push(context, MaterialPageRoute(builder: (context) => const UserProfileScreen()));
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF84BD00)),
              child: const Text('Complete Profile', style: TextStyle(color: Colors.black)),
            ),
          ],
        );
      },
    );
  }

  // Validate KYC and profile before proceeding
  bool _validateUserRequirements() {
    if (!_isKYCCompleted()) {
      _showKYCRequiredDialog();
      return false;
    }
    
    if (!_isProfileComplete()) {
      _showProfileRequiredDialog();
      return false;
    }
    
    return true;
  }
  
  Future<void> _scanQRCode() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => QRScannerScreen()),
    );
    
    if (result != null && result is String) {
      setState(() {
        _addressController.text = result;
      });
    }
  }
  
  Future<void> _handleWithdraw() async {
    // Check KYC and profile requirements first
    if (!_validateUserRequirements()) {
      return;
    }

    if (_addressController.text.isEmpty || _amountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    if (amount > _availableBalance) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Insufficient balance'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Send OTP first
    setState(() => _isLoading = true);
    final otpResult = await WalletService.sendOtp(purpose: 'crypto_withdraw');
    setState(() => _isLoading = false);

    if (otpResult['success'] != true) {
      _showError(otpResult['error'] ?? 'Failed to send verification code');
      return;
    }

    if (!mounted) return;

    // Navigate to OTP Screen
    final String? email = await AuthService.getUserEmail();
    final verified = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OtpVerificationScreen(
          email: email,
          onVerify: (otp) => WalletService.withdrawCrypto(
            coin: _selectedCoin,
            network: _selectedNetwork,
            address: _addressController.text,
            amount: amount,
            otp: otp,
          ).then((res) => {
            'success': res != null && res['success'] == true,
            'message': res != null ? (res['error'] ?? res['message']) : 'Withdrawal failed'
          }),
          onResend: () => WalletService.sendOtp(purpose: 'crypto_withdraw'),
        ),
      ),
    );
    
    if (verified == true) {
      // Log successful withdrawal notification
      await NotificationService.addNotification(
        title: 'Withdrawal Initiated',
        message: 'Your withdrawal of $amount $_selectedCoin to ${_addressController.text.substring(0, 6)}... has been submitted.',
        type: NotificationType.transaction,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Withdrawal successful'),
          backgroundColor: Color(0xFF84BD00),
        ),
      );
      
      // IMMEDIATE BALANCE REFRESH AFTER WITHDRAWAL
      debugPrint('WithdrawScreen: Triggering immediate balance refresh after withdrawal...');
      await Future.wait([
        unified.UnifiedWalletService.refreshAllBalances(),
        AutoRefreshService.forceRefreshAll(),
      ]);
      
      Navigator.of(context).pop();
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Withdraw',
          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: _isLoading 
      ? const Center(child: BitcoinLoadingIndicator(size: 40))
      : SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Coin Selector
              const Text(
                'Coin',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF333333)),
                ),
                child: ListTile(
                  leading: _buildCoinIcon(_selectedCoin),
                  title: Text(_selectedCoin, style: const TextStyle(color: Colors.white)),
                  trailing: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF6C7278)),
                  onTap: _showCoinSelector,
                ),
              ),
              
              const SizedBox(height: 24),

              // Address Field
              const Text(
                'Recipient Address',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF333333)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Address Input Row
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          // Wallet Icon Badge
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFF84BD00).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.account_balance_wallet, color: Color(0xFF84BD00), size: 20),
                          ),
                          const SizedBox(width: 12),
                          // Address Input Field
                          Expanded(
                            child: TextField(
                              controller: _addressController,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                              decoration: const InputDecoration(
                                hintText: 'Enter wallet address',
                                hintStyle: TextStyle(
                                  color: Color(0xFF6C7278),
                                  fontSize: 16,
                                ),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Divider with Actions
                    Container(
                      height: 1,
                      color: const Color(0xFF333333),
                    ),
                    // Action Buttons Row
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Scan QR Button
                          _buildAddressActionButton(
                            icon: Icons.qr_code_scanner,
                            label: 'Scan QR',
                            onTap: _scanQRCode,
                          ),
                          Container(width: 1, height: 24, color: const Color(0xFF333333)),
                          // Paste Button
                          _buildAddressActionButton(
                            icon: Icons.content_paste,
                            label: 'Paste',
                            onTap: () async {
                              final clipboard = await Clipboard.getData('text/plain');
                              if (clipboard?.text != null) {
                                _addressController.text = clipboard!.text!;
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),

              // KYC Requirement Warning
              if (!_isKYCCompleted())
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.orange.withOpacity(0.15), Colors.red.withOpacity(0.1)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.orange.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.verified_user_outlined,
                              color: Colors.orange,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'KYC Verification Required',
                                  style: TextStyle(
                                    color: Colors.orange,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Complete KYC verification to withdraw funds',
                                  style: TextStyle(
                                    color: Colors.orange,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () async {
                            final url = Uri.parse('https://creddx.com/profile/kyc');
                            if (await canLaunchUrl(url)) {
                              await launchUrl(url, mode: LaunchMode.externalApplication);
                              // Refresh status after user returns
                              await Future.delayed(const Duration(seconds: 2));
                              if (mounted) {
                                // Refresh user data to get updated KYC status
                                await _userService.fetchProfileDataFromAPI();
                                setState(() {});
                              }
                            } else {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Could not open KYC page. Please try again.'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Complete KYC Now',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              
              const SizedBox(height: 24),
              
              // Network Field
              const Text(
                'Network',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF333333)),
                ),
                child: ListTile(
                  title: Text(_selectedNetwork, style: const TextStyle(color: Colors.white)),
                  trailing: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF6C7278)),
                  onTap: _showNetworkSelector,
                ),
              ),
              
              const SizedBox(height: 24),

              // Withdrawal Amount
              const Text(
                'Withdrawal Amount',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 12),

              // Modern Amount Input
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF333333)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Amount Input Row
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          // Coin Icon Badge
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFF84BD00).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                _selectedCoin.substring(0, _selectedCoin.length > 3 ? 3 : _selectedCoin.length),
                                style: const TextStyle(
                                  color: Color(0xFF84BD00),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Input Field
                          Expanded(
                            child: TextField(
                              controller: _amountController,
                              keyboardType: TextInputType.numberWithOptions(decimal: true),
                              onChanged: _onAmountChanged,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w600,
                              ),
                              decoration: const InputDecoration(
                                hintText: '0.00',
                                hintStyle: TextStyle(
                                  color: Color(0xFF6C7278),
                                  fontSize: 24,
                                  fontWeight: FontWeight.w600,
                                ),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                          // Coin Symbol
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF333333),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _selectedCoin,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Divider
                    Container(
                      height: 1,
                      color: const Color(0xFF333333),
                    ),
                    // Available Balance Row
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          const Icon(Icons.account_balance_wallet_outlined, color: Color(0xFF6C7278), size: 16),
                          const SizedBox(width: 8),
                          const Text(
                            'Available: ',
                            style: TextStyle(color: Color(0xFF6C7278), fontSize: 13),
                          ),
                          _isFetchingBalance
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF84BD00),
                                  ),
                                )
                              : Text(
                                  '${_availableBalance.toStringAsFixed(2)} $_selectedCoin',
                                  style: const TextStyle(
                                    color: Color(0xFF84BD00),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),

              // Summary Section
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF333333)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF84BD00).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.receipt_long, color: Color(0xFF84BD00), size: 18),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Summary',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Divider
                    Container(height: 1, color: const Color(0xFF333333)),
                    // Summary Rows
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          // You Send
                          _buildSummaryRow(
                            label: 'You Send',
                            value: _amountController.text.isNotEmpty
                                ? '${(double.tryParse(_amountController.text) ?? 0.0).toStringAsFixed(2)} $_selectedCoin'
                                : '0.00 $_selectedCoin',
                            valueColor: Colors.white,
                          ),
                          const SizedBox(height: 12),
                          // Network Fee
                          _buildSummaryRow(
                            label: 'Network Fee',
                            value: _isFetchingFees
                                ? 'Calculating...'
                                : '${_withdrawalFees.toStringAsFixed(2)} $_selectedCoin',
                            valueColor: const Color(0xFF6C7278),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Divider(color: Color(0xFF333333), height: 1),
                          ),
                          // Recipient Receives
                          _buildSummaryRow(
                            label: 'Recipient Receives',
                            value: '${(_amountController.text.isNotEmpty
                                    ? (double.tryParse(_amountController.text) ?? 0.0) - _withdrawalFees
                                    : 0.0).toStringAsFixed(2)} $_selectedCoin',
                            valueColor: const Color(0xFF84BD00),
                            isBold: true,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),

              // Recent Transactions Section
              if (_recentTransactions.isNotEmpty || _isLoadingTransactions) ...[
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF333333)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF84BD00).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.history, color: Color(0xFF84BD00), size: 18),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Recent Transactions',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Divider
                      Container(height: 1, color: const Color(0xFF333333)),
                      // Transaction List
                      if (_isLoadingTransactions)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator(color: Color(0xFF84BD00))),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _recentTransactions.length,
                          separatorBuilder: (_, __) => Container(height: 1, color: const Color(0xFF333333)),
                          itemBuilder: (context, index) {
                            final tx = _recentTransactions[index];
                            return ListTile(
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: (tx['type'] == 'withdraw' ? Colors.red : const Color(0xFF84BD00)).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  tx['type'] == 'withdraw' ? Icons.arrow_outward : Icons.arrow_downward,
                                  color: tx['type'] == 'withdraw' ? Colors.red : const Color(0xFF84BD00),
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                tx['title'] ?? 'Transaction',
                                style: const TextStyle(color: Colors.white, fontSize: 14),
                              ),
                              subtitle: Text(
                                tx['date'] ?? '',
                                style: const TextStyle(color: Color(0xFF6C7278), fontSize: 12),
                              ),
                              trailing: Text(
                                '${tx['type'] == 'withdraw' ? '-' : '+'}${tx['amount'] ?? '0.00'} ${tx['coin'] ?? 'USDT'}',
                                style: TextStyle(
                                  color: tx['type'] == 'withdraw' ? Colors.red : const Color(0xFF84BD00),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Withdraw Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _handleWithdraw,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF84BD00),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Withdraw',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
    );
  }
  
  Widget _buildCoinIcon(String symbol) {
    final coin = _coins.firstWhere(
      (c) => c.symbol == symbol,
      orElse: () => Coin(id: '', name: symbol, symbol: symbol, icon: '', networks: []),
    );
    return _buildCoinIconFromCoin(coin);
  }

  Widget _buildCoinIconFromCoin(Coin coin) {
    final iconUrl = coin.icon;
    
    if (iconUrl.isNotEmpty) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Image.network(
            iconUrl,
            width: 40,
            height: 40,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return CoinIconMapper.getCoinIcon(coin.symbol, size: 40);
            },
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF84BD00).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF84BD00),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
    }
    
    return CoinIconMapper.getCoinIcon(coin.symbol, size: 40);
  }

  Widget _buildSummaryRow({
    required String label,
    required String value,
    required Color valueColor,
    bool isBold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: const Color(0xFF6C7278),
            fontSize: 14,
            fontWeight: isBold ? FontWeight.w500 : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 14,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildAddressActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFF84BD00), size: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF84BD00),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _balanceSubscription?.cancel();
    _addressController.dispose();
    _amountController.dispose();
    super.dispose();
  }
  
  void _showCoinSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Select Coin',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ..._coins.map((coin) => ListTile(
              leading: _buildCoinIconFromCoin(coin),
              title: Text(
                coin.name,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              subtitle: Text(
                coin.symbol,
                style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 14),
              ),
              onTap: () {
                Navigator.pop(context);
                _onCoinChanged(coin.symbol);
              },
            )),
          ],
        ),
      ),
    );
  }
  
  void _showNetworkSelector() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          constraints: const BoxConstraints(maxHeight: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Select Network',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView(
                  shrinkWrap: true,
                  children: _networks.map((network) => ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: network.isActive ? const Color(0xFF84BD00).withOpacity(0.2) : const Color(0xFF6C7278).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        Icons.network_check,
                        color: network.isActive ? const Color(0xFF84BD00) : const Color(0xFF6C7278),
                        size: 20,
                      ),
                    ),
                    title: Text(
                      '${network.name} (${network.type})${network.fee != null ? ' — Fee: ${network.fee!.toStringAsFixed(0)} USD' : ''}',
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    trailing: network.isActive
                        ? const Icon(Icons.check_circle, color: Color(0xFF84BD00), size: 20)
                        : null,
                    onTap: network.isActive
                        ? () {
                            Navigator.pop(context);
                            _onNetworkChanged(network.name);
                          }
                        : null,
                  )).toList(),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF333333),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
