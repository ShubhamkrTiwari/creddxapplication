import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'confirm_order_screen.dart';
import 'otp_verification_screen.dart';
import 'wallet_history_screen.dart';
import '../services/wallet_service.dart';
import '../services/socket_service.dart';
import '../services/unified_wallet_service.dart' as unified;

class SendScreen extends StatefulWidget {
  const SendScreen({super.key});

  @override
  State<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen> with SingleTickerProviderStateMixin {
  final _recipientController = TextEditingController();
  final _amountController = TextEditingController();
  final _recipientUidController = TextEditingController();
  final _internalAmountController = TextEditingController();
  String _selectedCrypto = 'BTC';
  String _selectedNetwork = 'Bitcoin Network';
  String _selectedInternalCoin = 'USDT';
  List<String> _cryptoOptions = ['BTC', 'ETH', 'USDT', 'BNB'];
  List<String> _networkOptions = ['Bitcoin Network', 'Ethereum Network', 'BNB Smart Chain'];
  List<Map<String, dynamic>> _coins = [];
  bool _isLoading = true;
  bool _isInternalLoading = false;
  double _availableBalance = 0.0;
  late TabController _tabController;
  StreamSubscription? _balanceSubscription;
  StreamSubscription? _unifiedWalletSubscription;
  
  // InterSend History related
  bool _showInterSendHistory = false;
  bool _isLoadingInterSendHistory = false;
  List<dynamic> _interSendHistory = [];
  String? _currentUserId;

  Future<String?> _getCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_id');
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 1, vsync: this);
    _fetchCryptoData();
    _fetchBalance();
    _subscribeToBalance();
    _subscribeToUnifiedWallet();
    _getCurrentUserId().then((id) {
      setState(() => _currentUserId = id);
      _fetchInterSendHistory();
    });
  }

  Future<void> _fetchInterSendHistory() async {
    setState(() => _isLoadingInterSendHistory = true);
    try {
      final result = await WalletService.getInternalTransferHistory(limit: 50);
      debugPrint('=== InterSend History API Response ===');
      debugPrint('Result: $result');
      if (mounted && result['success'] == true) {
        setState(() {
          final data = result['data'];
          if (data is List) {
            _interSendHistory = data;
          } else if (data is Map && data['transfers'] != null) {
            _interSendHistory = data['transfers'];
          } else if (data is Map && data['history'] != null) {
            _interSendHistory = data['history'];
          } else if (data is Map && data['transactions'] != null) {
            _interSendHistory = data['transactions'];
          }
          // Debug: print first item keys if available
          if (_interSendHistory.isNotEmpty && _interSendHistory[0] is Map) {
            debugPrint('First transfer item keys: ${(_interSendHistory[0] as Map).keys.toList()}');
            debugPrint('First transfer item: ${_interSendHistory[0]}');
          }
          _isLoadingInterSendHistory = false;
        });
      } else {
        setState(() => _isLoadingInterSendHistory = false);
      }
    } catch (e) {
      debugPrint('Error fetching InterSend history: $e');
      if (mounted) {
        setState(() => _isLoadingInterSendHistory = false);
      }
    }
  }

  void _subscribeToUnifiedWallet() {
    _unifiedWalletSubscription = unified.UnifiedWalletService.walletBalanceStream.listen((walletBalance) {
      if (mounted && walletBalance != null) {
        setState(() {
          // For user-to-user transfer, show Main wallet USDT balance as available
          // This is the balance that can actually be transferred to another user
          final mainBalance = unified.UnifiedWalletService.mainUSDTBalance;
          _availableBalance = mainBalance;
          debugPrint('Send Screen: Main wallet balance updated: $_availableBalance USDT');
        });
      }
    });
  }

  Future<void> _fetchBalance() async {
    // Use UnifiedWalletService for consistent and accurate balance data
    await unified.UnifiedWalletService.refreshAllBalances();
    
    if (mounted) {
      setState(() {
        // For user-to-user transfer, show Main wallet USDT balance as available
        final mainBalance = unified.UnifiedWalletService.mainUSDTBalance;
        _availableBalance = mainBalance;
        debugPrint('Send Screen: Main wallet balance fetched: $_availableBalance USDT');
      });
    }
  }

  void _subscribeToBalance() {
    _balanceSubscription = SocketService.balanceStream.listen((data) {
      if (mounted && (data['type'] == 'wallet_summary_update' || data['type'] == 'wallet_summary')) {
        // Socket updates are handled by UnifiedWalletService, which will trigger _subscribeToUnifiedWallet
        debugPrint('Send Screen: Socket balance update received, will be processed by UnifiedWalletService');
      }
    });
  }

  Future<void> _sendInternalTransfer() async {
    // Input validations before OTP
    if (_selectedInternalCoin.isEmpty) {
      _showError('Select an asset to continue.');
      return;
    }

    if (_recipientUidController.text.isEmpty) {
      _showError('Enter recipient UID.');
      return;
    }

    if (_internalAmountController.text.isEmpty) {
      _showError('Enter a valid amount.');
      return;
    }

    final amount = double.tryParse(_internalAmountController.text);
    if (amount == null || amount <= 0) {
      _showError('Enter a valid amount.');
      return;
    }

    if (amount > _availableBalance) {
      _showError('Insufficient balance. Please enter a lower amount.');
      return;
    }

    setState(() => _isInternalLoading = true);

    try {
      debugPrint('=== Starting OTP Send Process ===');
      // Step 1: Send OTP for internal transfer
      final otpResult = await WalletService.sendOtp(purpose: 'internal_transfer');
      
      debugPrint('OTP Result: $otpResult');

      bool? verified;
        if (otpResult['success'] == true || otpResult['status'] == 'success') {
        debugPrint('OTP sent successfully, navigating to OTP screen');
        if (!mounted) {
          debugPrint('Widget not mounted, returning');
          return;
        }

        _showSuccess('OTP sent successfully for proceeding the transfer!');

        // Reset loading state before navigation
        setState(() => _isInternalLoading = false);
        
        // Step 2: Navigate to OTP verification screen
        debugPrint('About to navigate to OTP verification screen');
        debugPrint('Context is valid: ${context.mounted}');
        try {
          debugPrint('Starting navigation to OTP screen...');
          verified = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (context) {
                debugPrint('Building OTP verification screen');
                return OtpVerificationScreen(
              onVerify: (otp) async {
                // Validate OTP length
                if (otp.length != 6) {
                  return {
                    'success': false,
                    'error': 'Please enter the 6-digit OTP.',
                  };
                }
                
                // Call transfer API with OTP
                final transferResult = await WalletService.internalTransfer(
                  receiverUid: _recipientUidController.text.trim(),
                  amount: amount,
                  otp: otp,
                );
                
                // Check for specific wrong OTP error
                if (transferResult['success'] != true) {
                  String errorMessage = transferResult['error'] ?? transferResult['message'] ?? 'Transfer failed';
                  
                  // Check if error indicates wrong OTP
                  if (_isWrongOtpError(errorMessage)) {
                    return {
                      'success': false,
                      'error': 'Wrong OTP. Please enter the correct OTP and try again.',
                    };
                  }
                  
                  // Check if error indicates wrong UID (backup validation)
                  if (_isWrongUidError(errorMessage)) {
                    return {
                      'success': false,
                      'error': 'Wrong UID. This user does not exist. Please check the UID and try again.',
                    };
                  }
                }
                
                return transferResult;
              },
              onResend: () => WalletService.sendOtp(purpose: 'internal_transfer'),
            );
            },
          ),
        );
          debugPrint('Navigation completed successfully. Verified: $verified');
        } catch (navError) {
          debugPrint('Navigation error: $navError');
          _showError('Failed to open OTP screen. Please try again.');
        } finally {
          // Reset loading state after navigation
          if (mounted) {
            setState(() => _isInternalLoading = false);
          }
        }

        // Step 3: Handle transfer success
        if (verified == true) {
          if (mounted) {
            _showSuccess('Transfer completed successfully. Funds have been credited instantly.');
            _recipientUidController.clear();
            _internalAmountController.clear();

            // Show InterSend history view instead of navigating away
            setState(() => _showInterSendHistory = true);
            _fetchInterSendHistory();
          }
        }
      } else {
        debugPrint('OTP send failed: $otpResult');
        // Show detailed error message for OTP delivery issues
        String errorMessage = otpResult['error'] ?? 'OTP sent failed. Please try again.';
        
        // Add specific guidance for common OTP issues
        if (errorMessage.toLowerCase().contains('network') || 
            errorMessage.toLowerCase().contains('connection')) {
          errorMessage += '\nPlease check your internet connection and try again.';
        } else if (errorMessage.toLowerCase().contains('rate') || 
                   errorMessage.toLowerCase().contains('limit')) {
          errorMessage += '\nPlease wait a few minutes before requesting another OTP.';
        } else if (errorMessage.toLowerCase().contains('phone') || 
                   errorMessage.toLowerCase().contains('email')) {
          errorMessage += '\nPlease ensure your registered email/phone number is correct.';
        }
        
        debugPrint('Showing error message: $errorMessage');
        _showError(errorMessage);
      }
    } catch (e) {
      debugPrint('Exception in _sendInternalTransfer: $e');
      if (mounted) {
        _showError('Transfer failed. Please try again later.');
      }
    } finally {
      if (mounted) {
        setState(() => _isInternalLoading = false);
      }
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showSuccess(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFF84BD00),
        ),
      );
    }
  }

  // Helper method to validate UID format
  bool _isValidUidFormat(String uid) {
    // Remove any whitespace and convert to uppercase for validation
    final cleanUid = uid.trim().toUpperCase();
    
    // Accept any non-empty string as valid UID format
    // Let the server handle the actual validation
    if (cleanUid.isNotEmpty && cleanUid.length >= 3) {
      return true;
    }
    
    return false;
  }

  // Helper method to detect wrong OTP errors
  bool _isWrongOtpError(String errorMessage) {
    final lowerError = errorMessage.toLowerCase();
    return lowerError.contains('wrong otp') ||
           lowerError.contains('incorrect otp') ||
           lowerError.contains('invalid otp') ||
           lowerError.contains('otp mismatch') ||
           lowerError.contains('invalid verification') ||
           lowerError.contains('verification failed');
  }

  // Helper method to detect wrong UID errors
  bool _isWrongUidError(String errorMessage) {
    final lowerError = errorMessage.toLowerCase();
    return lowerError.contains('wrong uid') ||
           lowerError.contains('invalid uid') ||
           lowerError.contains('user not found') ||
           lowerError.contains('recipient not found') ||
           lowerError.contains('user does not exist') ||
           lowerError.contains('invalid recipient');
  }
  
  Future<void> _fetchCryptoData() async {
    try {
      final coins = await WalletService.getAllCoins();
      if (mounted) {
        setState(() {
          _coins = coins;
          _cryptoOptions = coins.map((coin) => (coin['symbol'] ?? 'BTC').toString()).toSet().toList();
          if (!_cryptoOptions.contains(_selectedCrypto)) {
            _selectedCrypto = _cryptoOptions.isNotEmpty ? _cryptoOptions.first : 'BTC';
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching crypto data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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
          'Send',
          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF84BD00),
          indicatorWeight: 3,
          labelColor: const Color(0xFF84BD00),
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 14),
          tabs: const [
            Tab(text: 'Inter Send'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Inter Send Tab
          _buildInterSendTab(),
        ],
      ),
    );
  }

  
  Widget _buildInterSendTab() {
    if (_showInterSendHistory) {
      return _buildInterSendHistoryView();
    }
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header info with History button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF84BD00).withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF84BD00).withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.send,
                    color: Color(0xFF84BD00),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Internal Transfer',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Send crypto instantly to another CreddX user with 0 fees',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                // History Button
                TextButton.icon(
                  onPressed: () {
                    setState(() => _showInterSendHistory = true);
                    _fetchInterSendHistory();
                  },
                  icon: const Icon(Icons.history, color: Color(0xFF84BD00), size: 18),
                  label: const Text(
                    'History',
                    style: TextStyle(color: Color(0xFF84BD00), fontSize: 12),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Coin Selection
          const Text(
            'Select Coin',
            style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF2A2A2C)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedInternalCoin,
                isExpanded: true,
                dropdownColor: const Color(0xFF1C1C1E),
                style: const TextStyle(color: Colors.white, fontSize: 16),
                items: ['USDT'].map((coin) {
                  return DropdownMenuItem(
                    value: coin,
                    child: Row(
                      children: [
                        _buildCoinIcon(coin),
                        const SizedBox(width: 12),
                        Text(coin),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedInternalCoin = value!;
                  });
                },
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Recipient UID
          const Text(
            'Recipient UID',
            style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF2A2A2C)),
            ),
            child: TextField(
              controller: _recipientUidController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Enter recipient UID (e.g., CRDX123456)',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 14),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.paste, color: Color(0xFF84BD00)),
                      onPressed: () async {
                        final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
                        if (clipboardData?.text != null) {
                          _recipientUidController.text = clipboardData!.text!;
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Amount
          const Text(
            'Amount',
            style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF2A2A2C)),
            ),
            child: TextField(
              controller: _internalAmountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white, fontSize: 18),
              decoration: InputDecoration(
                hintText: '0.00',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 18),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(left: 16, right: 8),
                  child: Text(
                    _selectedInternalCoin,
                    style: const TextStyle(
                      color: Color(0xFF84BD00),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Available balance
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Available: ${_availableBalance.toStringAsFixed(2)} $_selectedInternalCoin',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    _internalAmountController.text = _availableBalance.toStringAsFixed(2);
                  },
                  child: const Text(
                    'MAX',
                    style: TextStyle(
                      color: Color(0xFF84BD00),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Send Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isInternalLoading ? null : _sendInternalTransfer,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF84BD00),
                disabledBackgroundColor: const Color(0xFF84BD00).withOpacity(0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isInternalLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Send Now',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),

          const SizedBox(height: 16),

          // Info text
          Center(
            child: Text(
              'Transfers are instant and irreversible',
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInterSendHistoryView() {
    if (_isLoadingInterSendHistory) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF84BD00)),
      );
    }

    if (_interSendHistory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.history, size: 64, color: Colors.white24),
            const SizedBox(height: 16),
            const Text(
              'No Transfer History',
              style: TextStyle(color: Colors.white54, fontSize: 16),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() => _showInterSendHistory = false);
                  },
                  icon: const Icon(Icons.arrow_back, color: Colors.black, size: 18),
                  label: const Text(
                    'Back',
                    style: TextStyle(color: Colors.black),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF84BD00),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _fetchInterSendHistory,
                  icon: const Icon(Icons.refresh, color: Colors.black, size: 18),
                  label: const Text(
                    'Refresh',
                    style: TextStyle(color: Colors.black),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF84BD00),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Back button header
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              TextButton.icon(
                onPressed: () => setState(() => _showInterSendHistory = false),
                icon: const Icon(Icons.arrow_back, color: Color(0xFF84BD00)),
                label: const Text(
                  'Back to Transfer',
                  style: TextStyle(color: Color(0xFF84BD00)),
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: _fetchInterSendHistory,
                icon: const Icon(Icons.refresh, color: Color(0xFF84BD00)),
              ),
            ],
          ),
        ),
        // History list
        Expanded(
          child: RefreshIndicator(
            onRefresh: _fetchInterSendHistory,
            color: const Color(0xFF84BD00),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _interSendHistory.length,
              itemBuilder: (context, index) {
                final transfer = _interSendHistory[index] is Map<String, dynamic>
                    ? _interSendHistory[index] as Map<String, dynamic>
                    : Map<String, dynamic>.from(_interSendHistory[index]);
                
                // Debug: print all keys and values for this transfer
                debugPrint('=== Transfer Item $index ===');
                debugPrint('Current User ID: $_currentUserId');
                debugPrint('All fields: ${transfer.keys.toList()}');
                transfer.forEach((key, value) {
                  debugPrint('  $key: $value (${value?.runtimeType})');
                });
                
                // Helper function to extract UID from various field names
                String extractUid(Map<String, dynamic> data, List<String> fieldNames) {
                  for (final field in fieldNames) {
                    // Check direct field
                    if (data[field] != null) {
                      final value = data[field].toString().trim();
                      if (value.isNotEmpty && value != 'null' && value != 'Unknown' && value != 'undefined') {
                        return value;
                      }
                    }
                    // Check nested object
                    if (data[field] is Map) {
                      final nested = data[field] as Map;
                      for (final sub in ['uid', 'id', '_id', 'userId', 'UID']) {
                        if (nested[sub] != null) {
                          final nestedValue = nested[sub].toString().trim();
                          if (nestedValue.isNotEmpty && nestedValue != 'null') {
                            return nestedValue;
                          }
                        }
                      }
                    }
                  }
                  return 'Unknown';
                }
                
                // Helper function to extract name from various field names
                String extractName(Map<String, dynamic> data, List<String> fieldNames) {
                  for (final field in fieldNames) {
                    // Check direct field
                    if (data[field] != null) {
                      final value = data[field].toString().trim();
                      if (value.isNotEmpty && value != 'null' && value != 'Unknown' && value != 'undefined') {
                        return value;
                      }
                    }
                    // Check nested object for name
                    if (data[field] is Map) {
                      final nested = data[field] as Map;
                      for (final sub in ['name', 'username', 'fullName', 'displayName', 'userName']) {
                        if (nested[sub] != null) {
                          final nestedValue = nested[sub].toString().trim();
                          if (nestedValue.isNotEmpty && nestedValue != 'null') {
                            return nestedValue;
                          }
                        }
                      }
                    }
                  }
                  return 'Unknown';
                }
                
                // Field names for receiver (sent transfers)
                final receiverFields = [
                  'receiverUid', 'toUserId', 'recipientUid', 'toUser', 'receiver', 
                  'to', 'targetUid', 'targetUserId', 'receiverUserId', 'toUserUid', 
                  'destinationUid', 'receiver_id', 'to_id', 'recipient_id', 'target_id',
                  'receiverUID', 'toUID'
                ];
                
                // Field names for sender (received transfers)
                final senderFields = [
                  'senderUid', 'fromUserId', 'senderId', 'fromUser', 'sender', 
                  'from', 'sourceUid', 'sourceUserId', 'senderUserId', 'fromUserUid', 
                  'source_id', 'from_id', 'sender_id', 'senderUID', 'fromUID'
                ];
                
                // Extract both sender and receiver UIDs
                String receiverUid = extractUid(transfer, receiverFields);
                String senderUid = extractUid(transfer, senderFields);
                
                // Extract transfer type
                final String type = transfer['type']?.toString() ?? 'sent';
                
                // Extract UID from toFrom object if available (this is the actual UID from API)
                if (transfer['toFrom'] is Map) {
                  final toFromObj = transfer['toFrom'] as Map;
                  final toFromUid = toFromObj['uid']?.toString().trim();
                  if (toFromUid != null && toFromUid.isNotEmpty && toFromUid != 'null') {
                    if (type.toLowerCase() == 'sent') {
                      // toFrom.uid is the receiver's UID when we sent
                      receiverUid = toFromUid;
                      debugPrint('Item $index - Using toFrom.uid as receiverUid: $toFromUid');
                    } else {
                      // toFrom.uid is the sender's UID when we received
                      senderUid = toFromUid;
                      debugPrint('Item $index - Using toFrom.uid as senderUid: $toFromUid');
                    }
                  }
                }
                
                // Field names for receiver/sender names (direct fields)
                final receiverNameFields = ['receiverName', 'toUserName', 'recipientName', 'toName', 'receiverUsername', 'toUsername', 'receiver_user_name', 'to_user_name'];
                final senderNameFields = ['senderName', 'fromUserName', 'senderUsername', 'fromName', 'fromUsername', 'sender_user_name', 'from_user_name'];
                
                // Also check in nested user objects
                final nestedUserFields = ['receiver', 'sender', 'toUser', 'fromUser', 'recipient', 'user', 'to', 'from', 'toFrom'];
                
                // Extract names using dedicated name extractor
                String receiverName = extractName(transfer, receiverNameFields);
                String senderName = extractName(transfer, senderNameFields);
                
                // If names not found directly, try nested user objects
                // Special handling for toFrom field
                if (transfer['toFrom'] is Map) {
                  final toFromObj = transfer['toFrom'] as Map;
                  final toFromName = toFromObj['name']?.toString().trim();
                  if (toFromName != null && toFromName.isNotEmpty && toFromName != 'null') {
                    // toFrom contains the other party's name
                    if (type.toLowerCase() == 'sent') {
                      receiverName = toFromName;
                      debugPrint('Item $index - Found receiver name in toFrom.name: $toFromName');
                    } else {
                      senderName = toFromName;
                      debugPrint('Item $index - Found sender name in toFrom.name: $toFromName');
                    }
                  }
                }
                
                if (receiverName == 'Unknown') {
                  for (final field in nestedUserFields) {
                    if (transfer[field] is Map) {
                      final userObj = transfer[field] as Map;
                      for (final nameField in ['name', 'username', 'fullName', 'displayName']) {
                        if (userObj[nameField] != null) {
                          final val = userObj[nameField].toString().trim();
                          if (val.isNotEmpty && val != 'null') {
                            receiverName = val;
                            debugPrint('Item $index - Found receiver name in $field.$nameField: $val');
                            break;
                          }
                        }
                      }
                      if (receiverName != 'Unknown') break;
                    }
                  }
                }
                
                if (senderName == 'Unknown') {
                  for (final field in nestedUserFields) {
                    if (transfer[field] is Map) {
                      final userObj = transfer[field] as Map;
                      for (final nameField in ['name', 'username', 'fullName', 'displayName']) {
                        if (userObj[nameField] != null) {
                          final val = userObj[nameField].toString().trim();
                          if (val.isNotEmpty && val != 'null') {
                            senderName = val;
                            debugPrint('Item $index - Found sender name in $field.$nameField: $val');
                            break;
                          }
                        }
                      }
                      if (senderName != 'Unknown') break;
                    }
                  }
                }
                
                // Debug: show what was found for this specific item
                debugPrint('Item $index - receiverUid: $receiverUid, senderUid: $senderUid');
                debugPrint('Item $index - receiverName: $receiverName, senderName: $senderName');
                
                // Try to find ANY field with a UID-like value for debugging
                String? anyUidFound;
                for (final entry in transfer.entries) {
                  final val = entry.value?.toString() ?? '';
                  if (val.isNotEmpty && 
                      val != 'null' && 
                      val.length > 5 &&
                      (val.toUpperCase().startsWith('CRDX') || val.toUpperCase().startsWith('UID') || RegExp(r'^[A-Z0-9]{6,}$').hasMatch(val.toUpperCase()))) {
                    anyUidFound = val;
                    debugPrint('Item $index - Found UID-like value in ${entry.key}: $val');
                  }
                }
                
                // Try to find any name-like field for debugging
                for (final entry in transfer.entries) {
                  final key = entry.key.toString().toLowerCase();
                  final val = entry.value?.toString() ?? '';
                  if (val.isNotEmpty && val != 'null' && 
                      (key.contains('name') || key.contains('username')) &&
                      !key.contains('amount') && !key.contains('status')) {
                    debugPrint('Item $index - Found name-like field ${entry.key}: $val');
                  }
                }
                
                // Determine if this is sent or received
                bool isSent = transfer['type']?.toString().toLowerCase() == 'sent' ||
                              transfer['direction']?.toString().toLowerCase() == 'outgoing' ||
                              transfer['isSent'] == true ||
                              transfer['isOutgoing'] == true;
                bool isReceived = transfer['type']?.toString().toLowerCase() == 'received' ||
                                  transfer['direction']?.toString().toLowerCase() == 'incoming' ||
                                  transfer['isReceived'] == true ||
                                  transfer['isIncoming'] == true;
                
                // If no direction info, infer from which UID is present or compare with current user
                if (!isSent && !isReceived) {
                  if (_currentUserId != null) {
                    // Compare with current user ID to determine direction
                    if (senderUid == _currentUserId) {
                      isSent = true;
                      debugPrint('Item $index - Current user is sender');
                    } else if (receiverUid == _currentUserId) {
                      isReceived = true;
                      debugPrint('Item $index - Current user is receiver');
                    }
                  }
                  
                  // If still undetermined, use fallback logic
                  if (!isSent && !isReceived) {
                    if (receiverUid != 'Unknown' && senderUid == 'Unknown') {
                      isSent = true; // Only receiver known = we sent it
                    } else if (senderUid != 'Unknown' && receiverUid == 'Unknown') {
                      isReceived = true; // Only sender known = we received it
                    } else if (receiverUid != 'Unknown' && senderUid != 'Unknown') {
                      isSent = true; // Assume sent by default
                    }
                  }
                }
                
                // Use appropriate UID based on direction
                // If we sent, show receiver (who we sent to)
                // If we received, show sender (who sent to us)
                String displayUid = isReceived ? senderUid : receiverUid;
                
                // Additional check: if we have current user ID and both UIDs, make sure we show the OTHER person
                if (_currentUserId != null && senderUid != 'Unknown' && receiverUid != 'Unknown') {
                  if (displayUid == _currentUserId) {
                    // We're showing ourselves, switch to the other party
                    displayUid = isReceived ? receiverUid : senderUid;
                    debugPrint('Item $index - Switched displayUid to avoid showing current user');
                  }
                }
                
                // Fallback: if displayUid is Unknown, try to show any available UID
                if (displayUid == 'Unknown') {
                  if (receiverUid != 'Unknown') {
                    displayUid = receiverUid;
                  } else if (senderUid != 'Unknown') {
                    displayUid = senderUid;
                  } else if (anyUidFound != null) {
                    // Use any UID-like value we found during scanning
                    displayUid = anyUidFound;
                    debugPrint('Item $index - Using anyUidFound fallback: $displayUid');
                  } else {
                    // Last resort: show any non-empty field that looks like a UID
                    for (final entry in transfer.entries) {
                      final key = entry.key.toString().toLowerCase();
                      final value = entry.value?.toString() ?? '';
                      if (value.isNotEmpty && 
                          value != 'null' && 
                          (key.contains('uid') || key.contains('id') || key.contains('user')) &&
                          key != 'amount' && key != 'status' && key != 'type') {
                        displayUid = value;
                        debugPrint('Item $index - Fallback UID from field ${entry.key}: $displayUid');
                        break;
                      }
                    }
                  }
                }
                
                debugPrint('Item $index - FINAL displayUid: $displayUid (isReceived: $isReceived)');
                
                // Format UID for display - show exactly 8 digits
                String formattedUid = displayUid;
                // Remove any prefix like CRDX and extract only the numeric part
                String numericPart = displayUid.replaceAll(RegExp(r'[^0-9]'), '');
                if (numericPart.length >= 8) {
                  // Show last 8 digits
                  formattedUid = numericPart.substring(numericPart.length - 8);
                } else if (numericPart.isNotEmpty) {
                  // If less than 8 digits, pad with leading zeros or show as is
                  formattedUid = numericPart.padLeft(8, '0');
                }
                debugPrint('Item $index - Formatted UID: $formattedUid');
                
                // Determine display name - use name if available, otherwise formatted UID
                final String displayName = isReceived 
                    ? (senderName != 'Unknown' ? senderName : formattedUid)
                    : (receiverName != 'Unknown' ? receiverName : formattedUid);
                debugPrint('Item $index - Display Name: $displayName');
                
                final double amount = double.tryParse(transfer['amount']?.toString() ?? '0') ?? 0;
                final String coin = transfer['coin']?.toString() ?? transfer['asset']?.toString() ?? transfer['currency']?.toString() ?? 'USDT';
                
                // Handle status - can be string or number
                String statusStr = 'completed';
                if (transfer['status'] != null) {
                  final statusVal = transfer['status'];
                  if (statusVal is int) {
                    // Numeric status: 1=pending, 2=completed, 0/3=failed
                    if (statusVal == 1) statusStr = 'pending';
                    else if (statusVal == 2) statusStr = 'completed';
                    else statusStr = 'failed';
                  } else {
                    statusStr = statusVal.toString();
                  }
                }
                final String status = statusStr;
                
                // Parse date - try multiple possible time fields (time is the actual field from API)
                final List<String> timeFields = ['time', 'createdAt', 'created_at', 'timestamp', 'date', 'updatedAt', 'updated_at'];
                String? timeStr;
                for (final field in timeFields) {
                  if (transfer[field] != null && transfer[field].toString().isNotEmpty && transfer[field].toString() != 'null') {
                    timeStr = transfer[field].toString();
                    break;
                  }
                }
                
                debugPrint('Time string for item $index: $timeStr');
                
                DateTime date;
                if (timeStr != null && timeStr.isNotEmpty) {
                  // Try parsing ISO format
                  date = DateTime.tryParse(timeStr) ?? DateTime.now();
                  
                  // If parsing resulted in now (same as other items), try additional formats
                  if (date.isAfter(DateTime.now().subtract(const Duration(seconds: 1)))) {
                    // Try Unix timestamp (milliseconds or seconds)
                    final intMs = int.tryParse(timeStr);
                    if (intMs != null) {
                      // Check if it's milliseconds (13 digits) or seconds (10 digits)
                      if (timeStr.length >= 13) {
                        date = DateTime.fromMillisecondsSinceEpoch(intMs);
                      } else {
                        date = DateTime.fromMillisecondsSinceEpoch(intMs * 1000);
                      }
                    }
                  }
                } else {
                  date = DateTime.now();
                }
                
                final DateTime localDate = date.isUtc ? date.toLocal() : date;
                debugPrint('Parsed date for item $index: $localDate');
                
                // Status color
                Color statusColor = Colors.green;
                if (status.toLowerCase() == 'pending') {
                  statusColor = Colors.orange;
                } else if (status.toLowerCase() == 'failed' || status.toLowerCase() == 'rejected') {
                  statusColor = Colors.red;
                }
                
                // Icon based on type (sent/received) - use the isReceived we determined above
                final IconData typeIcon = isReceived ? Icons.arrow_downward : Icons.arrow_upward;
                final Color typeColor = isReceived ? Colors.green : const Color(0xFF84BD00);

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C1E),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: typeColor.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              typeIcon,
                              color: typeColor,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isReceived ? 'Received from $displayName' : 'Sent to $displayName',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                // Show UID as subtitle if name is available
                                if ((isReceived && senderName != 'Unknown') || (!isReceived && receiverName != 'Unknown'))
                                  Text(
                                    formattedUid,
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 11,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                const SizedBox(height: 4),
                                Text(
                                  DateFormat('MMM dd, yyyy • hh:mm a').format(localDate),
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              status.toUpperCase(),
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(color: Colors.white10, height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isReceived ? 'Received Amount' : 'Sent Amount',
                            style: const TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                          Text(
                            '${amount.toStringAsFixed(2)} $coin',
                            style: const TextStyle(
                              color: Color(0xFF84BD00),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCoinIcon(String coin) {
    String imagePath = 'assets/images/';
    switch (coin) {
      case 'BTC':
        imagePath += 'btc.png';
        break;
      case 'ETH':
        imagePath += 'eth.png';
        break;
      case 'BNB':
        imagePath += 'bnb.png';
        break;
      case 'USDT':
        imagePath += 'usdt.png';
        break;
      default:
        imagePath += 'btc.png';
    }

    return Image.asset(
      imagePath,
      width: 24,
      height: 24,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: const Color(0xFF84BD00).withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              coin[0],
              style: const TextStyle(
                color: Color(0xFF84BD00),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
    );
  }
  
  @override
  void dispose() {
    _balanceSubscription?.cancel();
    _unifiedWalletSubscription?.cancel();
    _tabController.dispose();
    _recipientController.dispose();
    _amountController.dispose();
    _recipientUidController.dispose();
    _internalAmountController.dispose();
    super.dispose();
  }

  Future<void> _scanQRCode() async {
    // Request camera permission
    var status = await Permission.camera.status;
    if (!status.isGranted) {
      status = await Permission.camera.request();
      if (!status.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Camera permission is required to scan QR codes'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    }

    // Navigate to QR scan screen
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const QRScanScreen()),
    );

    if (result != null && result is String) {
      _recipientController.text = result;
    }
  }
}

class QRScanScreen extends StatefulWidget {
  const QRScanScreen({super.key});

  @override
  State<QRScanScreen> createState() => _QRScanScreenState();
}

class _QRScanScreenState extends State<QRScanScreen> {
  bool isScanning = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Scan QR Code',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            flex: 5,
            child: MobileScanner(
              onDetect: (capture) {
                final List<Barcode> barcodes = capture.barcodes;
                for (final barcode in barcodes) {
                  if (barcode.rawValue != null && isScanning) {
                    setState(() {
                      isScanning = false;
                    });
                    Navigator.of(context).pop(barcode.rawValue);
                    break;
                  }
                }
              },
            ),
          ),
          Expanded(
            flex: 1,
            child: Center(
              child: isScanning
                  ? const Text(
                      'Scanning...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    )
                  : const Text(
                      'QR Code Found!',
                      style: TextStyle(color: Color(0xFF84BD00), fontSize: 16),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
