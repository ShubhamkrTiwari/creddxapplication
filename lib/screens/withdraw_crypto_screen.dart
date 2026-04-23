import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'qr_scanner_screen.dart';
import 'otp_verification_screen.dart';
import 'dart:async';
import '../services/socket_service.dart';
import '../services/wallet_service.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../widgets/bitcoin_loading_indicator.dart';
import '../utils/coin_icon_mapper.dart';

class WithdrawCryptoScreen extends StatefulWidget {
  const WithdrawCryptoScreen({super.key});

  @override
  State<WithdrawCryptoScreen> createState() => _WithdrawCryptoScreenState();
}

class _WithdrawCryptoScreenState extends State<WithdrawCryptoScreen> {
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
  
  @override
  void initState() {
    super.initState();
    _fetchData();
    _subscribeToBalanceUpdates();
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
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _isLoading ? null : _refreshData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: BitcoinLoadingIndicator(size: 50))
          : SafeArea(
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
                    _buildAmountInput(),
                    const SizedBox(height: 20),
                    _buildBalanceAndFeeInfo(),
                    const SizedBox(height: 30),
                    _buildWithdrawButton(),
                  ],
                ),
              ),
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
        onPressed: _processWithdrawal,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF84BD00),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text(
          'Withdraw',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Future<void> _refreshData() async {
    await _fetchData();
    await _fetchAvailableBalance();
    if (_coins.isNotEmpty) {
      await _updateNetworksForCoin(_coins.first);
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
