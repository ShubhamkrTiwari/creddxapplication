import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import 'otp_verification_screen.dart';
import 'kyc_digilocker_instruction_screen.dart';
import '../services/wallet_service.dart';
import '../utils/kyc_unlock_mixin.dart';
import '../services/socket_service.dart';
import '../services/unified_wallet_service.dart' as unified;

class SendScreen extends StatefulWidget {
  const SendScreen({super.key});

  @override
  State<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen> with SingleTickerProviderStateMixin, KYCUnlockMixin {
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 1, vsync: this);
    _fetchCryptoData();
    _fetchBalance();
    _subscribeToBalance();
    _subscribeToUnifiedWallet();
    _fetchInterSendHistory();
    // Fetch fresh KYC status from API
    refreshKYCStatus();
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

  String _formatHistoryDate(dynamic raw) {
    if (raw == null) return '';
    final str = raw.toString().trim();
    if (str.isEmpty || str == 'null') return '';

    DateTime? dt = DateTime.tryParse(str);
    if (dt == null) {
      final asInt = int.tryParse(str);
      if (asInt != null) {
        // seconds vs milliseconds
        dt = str.length >= 13
            ? DateTime.fromMillisecondsSinceEpoch(asInt)
            : DateTime.fromMillisecondsSinceEpoch(asInt * 1000);
      }
    }
    dt ??= DateTime.now();
    final local = dt.isUtc ? dt.toLocal() : dt;
    return DateFormat('MMM dd, yyyy, hh:mm a').format(local);
  }

  String _uidTail(String uid, {int keep = 8}) {
    final cleaned = uid.trim().replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    if (cleaned.isEmpty) return '';
    final tail = cleaned.length <= keep ? cleaned : cleaned.substring(cleaned.length - keep);
    return tail.toLowerCase();
  }

  String _formatUidForHistory(String uid) {
    final tail = _uidTail(uid);
    if (tail.isEmpty) return '...';
    return '...$tail';
  }

  String _extractOtherPartyUid(Map<String, dynamic> transfer) {
    // API often provides `toFrom` as the other party.
    final type = (transfer['type'] ?? transfer['direction'] ?? '').toString().toLowerCase();
    if (transfer['toFrom'] is Map) {
      final m = Map<String, dynamic>.from(transfer['toFrom'] as Map);
      final uid = (m['uid'] ?? m['UID'] ?? m['userUid'] ?? m['id'] ?? m['_id'])?.toString();
      if (uid != null && uid.trim().isNotEmpty && uid != 'null') return uid.trim();
    }

    // Fallback fields.
    final sentFields = [
      'receiverUid',
      'receiverUID',
      'toUserUid',
      'toUID',
      'toUserId',
      'recipientUid',
      'recipientId',
      'to',
      'receiver',
    ];
    final recvFields = [
      'senderUid',
      'senderUID',
      'fromUserUid',
      'fromUID',
      'fromUserId',
      'senderId',
      'from',
      'sender',
    ];

    List<String> fields = type == 'received' || type == 'receive' || type == 'incoming'
        ? recvFields
        : sentFields;

    for (final f in fields) {
      final v = transfer[f]?.toString();
      if (v != null && v.trim().isNotEmpty && v != 'null') return v.trim();
    }

    // Last resort: any uid-like field
    for (final entry in transfer.entries) {
      final k = entry.key.toString().toLowerCase();
      final v = entry.value?.toString().trim() ?? '';
      if (v.isEmpty || v == 'null') continue;
      if (k.contains('uid') || (k.contains('user') && k.contains('id'))) return v;
    }
    return '';
  }

  bool _isReceivedTransfer(Map<String, dynamic> transfer) {
    final type = (transfer['type'] ?? transfer['direction'] ?? '').toString().toLowerCase();
    if (type == 'received' || type == 'receive' || type == 'incoming') return true;
    if (type == 'sent' || type == 'send' || type == 'outgoing') return false;

    // Fallback to explicit booleans if present.
    if (transfer['isReceived'] == true || transfer['isIncoming'] == true) return true;
    if (transfer['isSent'] == true || transfer['isOutgoing'] == true) return false;
    return false; // default matches most of current usage
  }

  String _statusLabel(Map<String, dynamic> transfer) {
    final s = transfer['status'];
    if (s == null) return 'Completed';
    if (s is num) {
      if (s.toInt() == 1) return 'Pending';
      if (s.toInt() == 2) return 'Completed';
      return 'Failed';
    }
    final str = s.toString().toLowerCase();
    if (str.contains('pending') || str == '1') return 'Pending';
    if (str.contains('fail') || str.contains('reject') || str == '0' || str == '3') return 'Failed';
    return 'Completed';
  }

  Color _statusColor(String label) {
    switch (label.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'failed':
        return Colors.red;
      default:
        return const Color(0xFF84BD00);
    }
  }

  String _formatHistoryAmount(double amount) {
    final roundedInt = amount.roundToDouble();
    if ((amount - roundedInt).abs() < 0.0000001) return roundedInt.toStringAsFixed(0);
    return amount.toStringAsFixed(2);
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

  // Check if KYC is completed
  bool _isKYCCompleted() {
    return isKYCCompleted(); // From KYCUnlockMixin
  }

  // Show KYC verification required dialog
  void _showKYCRequiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: const Text(
            'KYC Verification Required',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'You need to complete KYC verification to send funds. Please complete your KYC process first.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
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

  Future<void> _sendInternalTransfer() async {
    // Check KYC requirement first
    if (!_isKYCCompleted()) {
      _showKYCRequiredDialog();
      return;
    }

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

          // KYC Requirement Warning
          if (!_isKYCCompleted())
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withOpacity(0.5)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orange,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'KYC Verification Required',
                          style: TextStyle(
                            color: Colors.orange,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Complete KYC verification to send funds',
                          style: TextStyle(
                            color: Colors.orange.withOpacity(0.8),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const KYCDigiLockerInstructionScreen()));
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Complete KYC',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),

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
        // Table header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFF2A2A2C), width: 1),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'Date',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.55),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'To',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.55),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Type',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.55),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Amount',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.55),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Currency',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.55),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Status',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.55),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // History list (table rows)
        Expanded(
          child: RefreshIndicator(
            onRefresh: _fetchInterSendHistory,
            color: const Color(0xFF84BD00),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _interSendHistory.length,
              separatorBuilder: (_, __) => const SizedBox.shrink(),
              itemBuilder: (context, index) {
                final transfer = _interSendHistory[index] is Map<String, dynamic>
                    ? _interSendHistory[index] as Map<String, dynamic>
                    : Map<String, dynamic>.from(_interSendHistory[index]);

                final isReceived = _isReceivedTransfer(transfer);
                final otherUid = _extractOtherPartyUid(transfer);
                final displayUid = _formatUidForHistory(otherUid);

                final coin = (transfer['coin'] ?? transfer['asset'] ?? transfer['currency'] ?? 'USDT').toString();
                final amount = double.tryParse(transfer['amount']?.toString() ?? '0') ?? 0.0;

                final dateStr = _formatHistoryDate(
                  transfer['time'] ??
                      transfer['createdAt'] ??
                      transfer['created_at'] ??
                      transfer['timestamp'] ??
                      transfer['date'] ??
                      transfer['updatedAt'] ??
                      transfer['updated_at'],
                );

                final typeLabel = isReceived ? 'Received' : 'Sent';
                final typeColor = isReceived ? Colors.blueAccent : const Color(0xFF84BD00);

                final signedAmount = '${isReceived ? '+' : '-'}${_formatHistoryAmount(amount)}';
                final amountColor = isReceived ? Colors.green : const Color(0xFFFF6B6B);

                final status = _statusLabel(transfer);
                final statusColor = _statusColor(status);

                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Color(0xFF2A2A2C), width: 1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          dateStr,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 10,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          displayUid,
                          style: const TextStyle(
                            color: Color(0xFF84BD00),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          typeLabel,
                          style: TextStyle(
                            color: typeColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                            decorationColor: typeColor,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          signedAmount,
                          style: TextStyle(
                            color: amountColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          coin.toUpperCase(),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 10,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            status,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
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
