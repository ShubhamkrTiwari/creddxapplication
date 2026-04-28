import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'qr_scanner_screen.dart';
import 'otp_verification_screen.dart';
import 'dart:async';
import '../services/socket_service.dart';
import '../services/wallet_service.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../services/notification_service.dart';
import '../utils/kyc_unlock_mixin.dart';
import '../widgets/bitcoin_loading_indicator.dart';
import '../utils/coin_icon_mapper.dart';
import 'user_profile_screen.dart';
import 'kyc_digilocker_instruction_screen.dart';

class WithdrawCryptoScreen extends StatefulWidget {
  const WithdrawCryptoScreen({super.key});

  @override
  State<WithdrawCryptoScreen> createState() => _WithdrawCryptoScreenState();
}

class _WithdrawCryptoScreenState extends State<WithdrawCryptoScreen> with KYCUnlockMixin {
  final _addressController = TextEditingController();
  final _amountController = TextEditingController();
  String _selectedCoin = 'USDT';
  String _selectedNetwork = 'TRC20';
  List<Coin> _coins = [];
  List<Network> _networks = [];
  bool _isLoading = true;
  bool _isLoadingNetworks = false;
  bool _isFetchingBalance = false;
  bool _isFetchingFees = false;
  double _availableBalance = 0.0;
  double _withdrawalFees = 0.0;
  String? _errorMessage;
  List<dynamic> _recentTransactions = [];
  bool _isLoadingTransactions = false;
  StreamSubscription? _balanceSubscription;

  // History related state variables
  bool _showHistory = false;
  bool _isLoadingHistory = false;
  List<dynamic> _withdrawalHistory = [];
  String? _historyError;
  
  final UserService _userService = UserService();
  
  @override
  void initState() {
    super.initState();
    _fetchData();
    _subscribeToBalanceUpdates();
  }

  // Check if KYC is completed
  bool _isKYCCompleted() {
    return isKYCCompleted(); // Use the mixin method
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
            'You need to complete KYC verification to withdraw crypto. Please complete your KYC process first.',
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
                Navigator.push(context, MaterialPageRoute(builder: (context) => const KYCDigiLockerInstructionScreen()));
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
            'Please complete your profile information (email and phone number) to withdraw crypto.',
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
  
  void _subscribeToBalanceUpdates() {
    _balanceSubscription = SocketService.balanceStream.listen((data) {
      if (mounted && data['type'] == 'balance_update') {
        final payload = data['data'] ?? data;
        
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
      _errorMessage = null;
    });
    
    try {
      final coinsData = await WalletService.getAllCoins();
      
      if (mounted) {
        setState(() {
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
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load coins: $e';
        });
      }
    }
  }
  
  Future<void> _updateNetworksForCoin(Coin coin) async {
    setState(() {
      _isLoadingNetworks = true;
    });

    // Use hardcoded network list: Ethereum, Binance Smart Chain, Polygon
    await Future.delayed(const Duration(milliseconds: 300)); // Simulate loading
    
    if (mounted) {
      setState(() {
        _networks = [
          Network(name: 'Ethereum', type: 'ERC20', isActive: true, fee: 0.0),
          Network(name: 'Binance Smart Chain', type: 'BEP20', isActive: true, fee: 0.0),
          Network(name: 'Polygon', type: 'POLYGON', isActive: true, fee: 0.0),
        ];
        _selectedNetwork = _networks.first.name;
        _isLoadingNetworks = false;
      });
    }
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

    final result = await WalletService.getAllWalletBalances();

    if (mounted) {
      setState(() {
        if (result['success'] == true && result['data'] != null) {
          final data = result['data'];
          double availableBalance = 0.0;

          if (data is Map) {
            // Check mainBalance format first
            if (data['mainBalance'] is Map) {
              final mainBalance = data['mainBalance'] as Map;
              final usdtBalance = mainBalance['USDT'];
              if (usdtBalance != null) {
                availableBalance = double.tryParse(usdtBalance.toString()) ?? 0.0;
              }
            }

            // If still 0, check wallet types (spot, p2p, bot, etc.)
            if (availableBalance == 0.0) {
              final walletTypes = ['spot', 'p2p', 'bot', 'demo_bot', 'main'];
              for (String type in walletTypes) {
                if (data[type] is Map && data[type]['balances'] != null) {
                  final balances = data[type]['balances'];
                  if (balances is List) {
                    for (var b in balances) {
                      if (b['coin']?.toString().toUpperCase() == 'USDT') {
                        availableBalance += double.tryParse(b['available']?.toString() ?? '0') ?? 0.0;
                      }
                    }
                  } else if (balances is Map && balances['USDT'] is Map) {
                    final usdtData = balances['USDT'];
                    availableBalance += double.tryParse(usdtData['available']?.toString() ?? '0') ?? 0.0;
                  }
                }
              }
            }

            // Check direct available fields
            if (availableBalance == 0.0) {
              availableBalance = double.tryParse(
                data['available_balance']?.toString() ??
                data['availableBalance']?.toString() ??
                data['available']?.toString() ??
                data['balance']?.toString() ??
                data['usdt_available']?.toString() ??
                '0.0'
              ) ?? 0.0;
            }
          }

          _availableBalance = availableBalance;
        } else {
          _errorMessage = result['error']?.toString();
        }
        _isFetchingBalance = false;
      });
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
        if (result != null && result['success'] == true) {
          _withdrawalFees = double.tryParse(result['fee']?.toString() ?? '0.0') ?? 0.0;
        } else {
          _withdrawalFees = 0.0;
        }
        _isFetchingFees = false;
      });
    }
  }

  Future<void> _processWithdrawal() async {
    if (_addressController.text.isEmpty) {
      _showErrorSnackBar('Please enter a valid address');
      return;
    }
    
    if (_amountController.text.isEmpty || double.tryParse(_amountController.text) == null) {
      _showErrorSnackBar('Please enter a valid amount');
      return;
    }

    final amount = double.parse(_amountController.text);
    if (amount <= 0) {
      _showErrorSnackBar('Amount must be greater than 0');
      return;
    }

    if (amount > _availableBalance) {
      _showErrorSnackBar('Insufficient balance');
      return;
    }

    final shouldProceed = await _showWithdrawalConfirmation();
    if (!shouldProceed) return;

    _showLoadingDialog();

    try {
      final email = await AuthService.getUserEmail();

      if (email == null || email.isEmpty) {
        Navigator.pop(context);
        _showErrorSnackBar('User email not found');
        return;
      }

      final result = await WalletService.initiateWithdrawal(
        email: email,
        coin: _selectedCoin,
        network: _selectedNetwork,
        address: _addressController.text,
        amount: amount,
      );

      Navigator.pop(context);

      if (result == null) {
        _showErrorSnackBar('Failed to process withdrawal: No response from server');
        return;
      }

      if (result['success'] == true) {
        NotificationService.showSuccess(
          context: context,
          title: 'Withdrawal Initiated',
          message: 'Your withdrawal request has been submitted successfully',
        );
        
        _addressController.clear();
        _amountController.clear();
        _fetchAvailableBalance();
      } else {
        String errorMsg = result?['error']?.toString() ?? 'Withdrawal failed';
        if (result?['requiresEmailVerification'] == true) {
          _showEmailVerificationDialog();
        } else if (result?['requiresOTP'] == true) {
          _showOTPVerificationDialog();
        } else {
          _showErrorSnackBar(errorMsg);
        }
      }
    } catch (e) {
      Navigator.pop(context);
      _showErrorSnackBar('An error occurred: $e');
    }
  }

  Future<bool> _showWithdrawalConfirmation() async {
    final amount = double.parse(_amountController.text);
    final total = amount + _withdrawalFees;

    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E20),
          title: const Text(
            'Confirm Withdrawal',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildConfirmationRow('Coin', _selectedCoin),
              _buildConfirmationRow('Network', _selectedNetwork),
              _buildConfirmationRow('Amount', '$amount $_selectedCoin'),
              _buildConfirmationRow('Fee', '$_withdrawalFees $_selectedCoin'),
              const Divider(color: Colors.white24, height: 20),
              _buildConfirmationRow('Total', '$total $_selectedCoin', isBold: true),
              const SizedBox(height: 16),
              const Text(
                'Address:',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                _addressController.text,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF84BD00),
                foregroundColor: Colors.white,
              ),
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    ) ?? false;
  }

  Widget _buildConfirmationRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white54,
              fontSize: isBold ? 14 : 13,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: isBold ? 14 : 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: const Color(0xFF1E1E20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: Color(0xFF84BD00)),
                const SizedBox(height: 16),
                const Text(
                  'Processing Withdrawal...',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEmailVerificationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E20),
          title: const Text(
            'Email Verification Required',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'Please verify your email address before making withdrawals.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK', style: TextStyle(color: Color(0xFF84BD00))),
            ),
          ],
        );
      },
    );
  }

  void _showOTPVerificationDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OtpVerificationScreen(
          onVerify: (otp) async {
            final amount = double.parse(_amountController.text);
            final res = await WalletService.withdrawCrypto(
              coin: _selectedCoin,
              network: _selectedNetwork,
              address: _addressController.text,
              amount: amount,
              otp: otp,
            );

            bool success = res != null && res['success'] == true;
            if (success) {
              // Trigger global balance refresh after success
              WalletService.getAllWalletBalances();
            }

            return {
              'success': success,
              'message': res != null ? (res['error'] ?? res['message']) : 'Withdrawal failed'
            };
          },
          onResend: () => WalletService.sendOtp(purpose: 'crypto_withdraw'),
        ),
      ),
    ).then((verified) {
      if (verified == true) {
        NotificationService.showSuccess(
          context: context,
          title: 'Withdrawal Initiated',
          message: 'Your withdrawal request has been submitted successfully',
        );
        _addressController.clear();
        _amountController.clear();
        _fetchAvailableBalance();
      }
    });
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFFF3B30),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _scanQRCode() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const QRScannerScreen()),
    );
    
    if (result != null && result is String) {
      setState(() {
        _addressController.text = result;
      });
    }
  }

  void _showMaxAmount() {
    if (_availableBalance > 0) {
      setState(() {
        _amountController.text = _availableBalance.toStringAsFixed(6);
      });
      _fetchWithdrawalFees();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Withdraw Crypto',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton.icon(
            onPressed: _toggleHistory,
            icon: Icon(
              _showHistory ? Icons.add_circle_outline : Icons.history,
              color: const Color(0xFF84BD00),
              size: 20,
            ),
            label: Text(
              _showHistory ? 'Withdraw' : 'History',
              style: const TextStyle(
                color: Color(0xFF84BD00),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _isLoading ? null : _refreshData,
          ),
        ],
      ),
      body: _showHistory ? _buildHistoryView() : _buildWithdrawForm(),
    );
  }

  Widget _buildWithdrawForm() {
    if (_isLoading) {
      return const Center(child: BitcoinLoadingIndicator(size: 50));
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCoinSelector(),
            const SizedBox(height: 20),
            _buildNetworkSelector(),
            if (_isLoadingNetworks)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF84BD00),
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Loading networks...',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),
            _buildAddressInput(),
            const SizedBox(height: 20),
            
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
                                'Complete KYC verification to access this feature',
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
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const KYCDigiLockerInstructionScreen()));
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
            const SizedBox(height: 20),
            
            _buildAmountInput(),
            const SizedBox(height: 20),
            _buildBalanceAndFeeInfo(),
            const SizedBox(height: 30),
            _buildWithdrawButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryView() {
    if (_isLoadingHistory) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF84BD00),
        ),
      );
    }

    if (_historyError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              _historyError!,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadWithdrawalHistory,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF84BD00),
                foregroundColor: Colors.black,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_withdrawalHistory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.history, color: Colors.white38, size: 64),
            const SizedBox(height: 16),
            const Text(
              'No Withdrawal History',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your crypto withdrawal history will appear here',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _toggleHistory,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF84BD00),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('Make a Withdrawal'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadWithdrawalHistory,
      color: const Color(0xFF84BD00),
      backgroundColor: const Color(0xFF1C1C1E),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _withdrawalHistory.length,
        itemBuilder: (context, index) {
          final withdrawal = _withdrawalHistory[index];
          return _buildWithdrawalHistoryItem(withdrawal);
        },
      ),
    );
  }

  Widget _buildWithdrawalHistoryItem(Map<String, dynamic> withdrawal) {
    final amount = withdrawal['amount'] ?? withdrawal['total'] ?? withdrawal['value'] ?? '0';
    final status = withdrawal['status'] ?? withdrawal['transactionStatus'] ?? 'pending';
    final createdAt = withdrawal['createdAt'] ?? withdrawal['date'] ?? withdrawal['timestamp'];
    final coin = withdrawal['coin'] ?? withdrawal['currency'] ?? withdrawal['asset'] ?? 'USDT';
    final network = withdrawal['network'] ?? withdrawal['chain'] ?? withdrawal['blockchain'] ?? '';
    final address = withdrawal['address'] ?? withdrawal['toAddress'] ?? withdrawal['destination'] ?? '';
    final reference = withdrawal['referenceId'] ?? withdrawal['reference'] ?? withdrawal['id'] ?? withdrawal['_id'] ?? withdrawal['transactionId'] ?? '';

    Color statusColor;
    IconData statusIcon;
    switch (status.toString().toLowerCase()) {
      case 'completed':
      case 'success':
      case 'approved':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'pending':
      case 'processing':
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
        break;
      case 'failed':
      case 'rejected':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help;
    }

    String formattedDate = 'Unknown date';
    if (createdAt != null) {
      try {
        DateTime date;
        final createdAtStr = createdAt.toString();
        
        // Try parsing as ISO string first
        date = DateTime.tryParse(createdAtStr) ?? DateTime.now();
        
        // If parsing failed, try parsing as Unix timestamp
        if (date == DateTime.now() && createdAtStr.isNotEmpty) {
          try {
            final timestamp = int.tryParse(createdAtStr);
            if (timestamp != null) {
              date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
            }
          } catch (e) {
            // If all parsing fails, use current time
            date = DateTime.now();
          }
        }
        
        // Format to local time with proper 12-hour format
        formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(date.toLocal());
        
        // Debug logging to check the conversion
        debugPrint('Original createdAt: $createdAtStr');
        debugPrint('Parsed date: $date');
        debugPrint('Formatted date: $formattedDate');
        
      } catch (e) {
        debugPrint('Error parsing date: $e');
        formattedDate = createdAt.toString();
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2C2C2E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(statusIcon, color: statusColor, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Withdraw ${coin.toString().toUpperCase()}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  status.toString().toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Amount',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${double.tryParse(amount.toString())?.toStringAsFixed(6) ?? amount} ${coin.toString().toUpperCase()}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              if (network.toString().isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Network',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF84BD00).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        network.toString(),
                        style: const TextStyle(
                          color: Color(0xFF84BD00),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          if (address.toString().isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(color: Color(0xFF2C2C2E), height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text(
                  'To: ',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                Expanded(
                  child: Text(
                    address.toString(),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          const Divider(color: Color(0xFF2C2C2E), height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                formattedDate,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
              if (reference.toString().isNotEmpty)
                Text(
                  'Ref: ${reference.toString().substring(0, reference.toString().length > 8 ? 8 : reference.toString().length)}',
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCoinSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Coin',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E20),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            children: [
              CoinIconMapper.getCoinIcon(_selectedCoin, size: 32),
              const SizedBox(width: 12),
              Text(
                _selectedCoin,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNetworkSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Network',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _networks.isNotEmpty ? () => _showNetworkBottomSheet() : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E20),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF84BD00).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _selectedNetwork.isNotEmpty ? _selectedNetwork : 'Select Network',
                    style: const TextStyle(
                      color: Color(0xFF84BD00),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const Spacer(),
                const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
              ],
            ),
          ),
        ),
        if (_networks.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _isFetchingFees
                ? const Row(
                    children: [
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: Color(0xFF84BD00),
                        ),
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Fetching fee...',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  )
                : Text(
                    'Fee: ${_withdrawalFees.toStringAsFixed(6)} $_selectedCoin',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
          ),
      ],
    );
  }

  void _showNetworkBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E20),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select Network',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              ..._networks.map((network) {
                return GestureDetector(
                  onTap: () {
                    _onNetworkChanged(network.name);
                    Navigator.pop(context);
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: network.name == _selectedNetwork
                          ? const Color(0xFF84BD00).withOpacity(0.2)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Text(
                          network.name,
                          style: TextStyle(
                            color: network.name == _selectedNetwork
                                ? const Color(0xFF84BD00)
                                : Colors.white,
                            fontSize: 16,
                            fontWeight: network.name == _selectedNetwork
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                        const Spacer(),
                        if (network.name == _selectedNetwork)
                          const Icon(Icons.check, color: Color(0xFF84BD00), size: 20),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAddressInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Address',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E20),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _addressController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: 'Enter or paste address',
                    hintStyle: TextStyle(color: Colors.white38),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.qr_code_scanner, color: Color(0xFF84BD00)),
                onPressed: _scanQRCode,
              ),
              IconButton(
                icon: const Icon(Icons.paste, color: Colors.white54),
                onPressed: () async {
                  final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
                  if (clipboardData != null && clipboardData.text != null) {
                    _addressController.text = clipboardData.text!;
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAmountInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Amount',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E20),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  decoration: const InputDecoration(
                    hintText: '0.00',
                    hintStyle: TextStyle(color: Colors.white38),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 16),
                  ),
                  onChanged: (_) => _fetchWithdrawalFees(),
                ),
              ),
              GestureDetector(
                onTap: _showMaxAmount,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF84BD00).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'MAX',
                    style: TextStyle(
                      color: Color(0xFF84BD00),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBalanceAndFeeInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E20),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Available Balance',
                style: TextStyle(color: Colors.white54, fontSize: 14),
              ),
              _isFetchingBalance
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF84BD00),
                      ),
                    )
                  : Text(
                      '${_availableBalance.toStringAsFixed(6)} $_selectedCoin',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Network Fee',
                style: TextStyle(color: Colors.white54, fontSize: 14),
              ),
              _isFetchingFees
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF84BD00),
                      ),
                    )
                  : Text(
                      '${_withdrawalFees.toStringAsFixed(6)} $_selectedCoin',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWithdrawButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _handleConfirmAndSendOTP,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF84BD00),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text(
          'Confirm & Send OTP',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Future<void> _handleConfirmAndSendOTP() async {
    // Check KYC and profile requirements first
    if (!_validateUserRequirements()) {
      return;
    }

    // Validate inputs
    if (_addressController.text.isEmpty) {
      _showErrorSnackBar('Please enter a valid address');
      return;
    }
    
    if (_amountController.text.isEmpty || double.tryParse(_amountController.text) == null) {
      _showErrorSnackBar('Please enter a valid amount');
      return;
    }

    final amount = double.parse(_amountController.text);
    if (amount <= 0) {
      _showErrorSnackBar('Amount must be greater than 0');
      return;
    }

    if (amount > _availableBalance) {
      _showErrorSnackBar('Insufficient balance');
      return;
    }

    // Show confirmation dialog first
    final shouldProceed = await _showWithdrawalConfirmation();
    if (!shouldProceed) return;

    // Show loading
    _showLoadingDialog();

    try {
      // Step 1: Send OTP
      final otpResult = await WalletService.sendOtp(purpose: 'crypto_withdraw');
      
      Navigator.pop(context); // Close loading dialog

      if (otpResult['success'] != true) {
        _showErrorSnackBar(otpResult['error'] ?? 'Failed to send OTP');
        return;
      }

      if (!mounted) return;

      // Step 2: Navigate to OTP Verification Screen
      final bool? verified = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => OtpVerificationScreen(
            onVerify: (otp) async {
              final result = await WalletService.withdrawCrypto(
                coin: _selectedCoin,
                network: _selectedNetwork,
                address: _addressController.text,
                amount: amount,
                otp: otp,
              );
              
              bool success = result != null && result['success'] == true;
              if (success) {
                WalletService.getAllWalletBalances();
              }
              
              return {
                'success': success,
                'message': result != null ? (result['error'] ?? result['message']) : 'Withdrawal failed'
              };
            },
            onResend: () => WalletService.sendOtp(purpose: 'crypto_withdraw'),
          ),
        ),
      );

      // Step 3: If verified, navigate to success screen
      if (verified == true && mounted) {
        await NotificationService.addNotification(
          title: 'Crypto Withdrawal Initiated',
          message: 'Your withdrawal of $amount $_selectedCoin to ${_addressController.text.substring(0, 6)}... has been submitted.',
          type: NotificationType.transaction,
        );
        
        // Navigate to success screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => _buildSuccessScreen(amount),
          ),
        );
      }
    } catch (e) {
      Navigator.pop(context); // Close loading dialog if still showing
      _showErrorSnackBar('An error occurred: $e');
    }
  }

  Widget _buildSuccessScreen(double amount) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF84BD00).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF84BD00),
                  size: 100,
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Withdrawal Initiated',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Your crypto withdrawal request of $amount $_selectedCoin has been submitted successfully.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E20),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _buildSuccessDetailRow('Coin', _selectedCoin),
                    const SizedBox(height: 8),
                    _buildSuccessDetailRow('Network', _selectedNetwork),
                    const SizedBox(height: 8),
                    _buildSuccessDetailRow('Amount', '$amount $_selectedCoin'),
                    const SizedBox(height: 8),
                    _buildSuccessDetailRow('Address', '${_addressController.text.substring(0, 6)}...${_addressController.text.substring(_addressController.text.length > 6 ? _addressController.text.length - 6 : 0)}'),
                    const SizedBox(height: 8),
                    _buildSuccessDetailRow('Network Fee', '${_withdrawalFees.toStringAsFixed(6)} $_selectedCoin'),
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF84BD00),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    'Done',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 14)),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Future<void> _refreshData() async {
    await _fetchData();
    await _fetchAvailableBalance();
    if (_coins.isNotEmpty) {
      await _updateNetworksForCoin(_coins.first);
    }
  }

  Future<void> _loadWithdrawalHistory() async {
    setState(() {
      _isLoadingHistory = true;
      _historyError = null;
    });

    try {
      debugPrint('Withdraw Crypto Screen: Fetching crypto withdrawal history...');
      final result = await WalletService.getCryptoWithdrawalHistory(limit: 50);
      debugPrint('Withdraw Crypto Screen: API result: $result');

      if (result['success'] == true) {
        final data = result['data'];
        debugPrint('Withdraw Crypto Screen: Data type: ${data.runtimeType}');

        if (data != null && data is Map) {
          final transactions = data['transactions'];
          if (transactions is List) {
            setState(() {
              _withdrawalHistory = transactions;
            });
            debugPrint('Withdraw Crypto Screen: Loaded ${transactions.length} transactions');
          } else {
            setState(() {
              _withdrawalHistory = [];
            });
            debugPrint('Withdraw Crypto Screen: No transactions found in data');
          }
        } else if (data is List) {
          setState(() {
            _withdrawalHistory = data;
          });
          debugPrint('Withdraw Crypto Screen: Loaded ${data.length} transactions (direct list)');
        } else {
          setState(() {
            _withdrawalHistory = [];
          });
          debugPrint('Withdraw Crypto Screen: Empty or invalid data structure');
        }
      } else {
        setState(() {
          _historyError = result['error'] ?? 'Failed to load history';
        });
        debugPrint('Withdraw Crypto Screen: API error: ${result['error']}');
      }
    } catch (e, stackTrace) {
      setState(() {
        _historyError = 'Error: $e';
      });
      debugPrint('Withdraw Crypto Screen: Exception loading history: $e');
      debugPrint('Stack trace: $stackTrace');
    } finally {
      setState(() {
        _isLoadingHistory = false;
      });
    }
  }

  void _toggleHistory() {
    setState(() {
      _showHistory = !_showHistory;
    });
    if (_showHistory && _withdrawalHistory.isEmpty) {
      _loadWithdrawalHistory();
    }
  }

  @override
  void dispose() {
    _addressController.dispose();
    _amountController.dispose();
    _balanceSubscription?.cancel();
    super.dispose();
  }
}

class Coin {
  final String symbol;
  final String name;
  final List<Network> networks;

  Coin({
    required this.symbol,
    required this.name,
    required this.networks,
  });

  factory Coin.fromJson(Map<String, dynamic> json) {
    return Coin(
      symbol: json['symbol']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      networks: (json['networks'] as List? ?? [])
          .map((n) => Network.fromJson(n))
          .toList(),
    );
  }
}

class Network {
  final String name;
  final String type;
  final bool isActive;
  final double fee;

  Network({
    required this.name,
    required this.type,
    required this.isActive,
    required this.fee,
  });

  factory Network.fromJson(Map<String, dynamic> json) {
    return Network(
      name: json['name']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      isActive: json['isActive'] == true || json['isActive'] == 1 || json['isActive'] == 'true',
      fee: double.tryParse(json['fee']?.toString() ?? '0') ?? 0.0,
    );
  }
}
