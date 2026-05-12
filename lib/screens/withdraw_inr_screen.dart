import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/wallet_service.dart';
import '../services/notification_service.dart';
import '../services/unified_wallet_service.dart';
import '../services/socket_service.dart';
import '../services/user_service.dart';
import '../utils/kyc_unlock_mixin.dart';
import 'user_profile_screen.dart';
import 'update_profile_screen.dart';
import 'add_inr_bank_screen.dart';

class WithdrawINRScreen extends StatefulWidget {
  const WithdrawINRScreen({super.key});

  @override
  State<WithdrawINRScreen> createState() => _WithdrawINRScreenState();
}

class _WithdrawINRScreenState extends State<WithdrawINRScreen> with KYCUnlockMixin {
  bool _isLoading = false;
  final PageController _pageController = PageController();
  int _currentStep = 0; // 0: Select Bank, 1: Amount, 2: Review, 3: OTP
  
  List<Map<String, dynamic>> _bankAccounts = [];
  Map<String, dynamic>? _selectedBankAccount;
  
  double _availableBalance = 0.0;
  StreamSubscription? _balanceSubscription;
  
  final _amountController = TextEditingController();
  final _otpController = TextEditingController();
  
  bool _isSendingOTP = false;
  bool _isSubmittingWithdrawal = false;
  
  final UserService _userService = UserService();

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
    _setupBalanceListener();
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
            'You need to complete KYC verification to withdraw INR. Please complete your KYC process first.',
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
                            builder: (context) => const UpdateProfileScreen(),
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
            'Please complete your profile information (email and phone number) to withdraw INR.',
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
                Navigator.push(context, MaterialPageRoute(builder: (context) => const UpdateProfileScreen()));
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

  @override
  void dispose() {
    _balanceSubscription?.cancel();
    _pageController.dispose();
    _amountController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _setupBalanceListener() {
    _balanceSubscription = UnifiedWalletService.walletBalanceStream.listen((balance) {
      if (mounted) {
        // Use totalINRBalance to show funds from all sources (Main, Bot, Spot)
        final newInr = UnifiedWalletService.totalINRBalance;
        debugPrint('WithdrawINRScreen: Wallet stream update - Total INR: $newInr');
        setState(() {
          _availableBalance = newInr;
        });
      }
    });
    // Initial value
    final initialInr = UnifiedWalletService.totalINRBalance;
    if (initialInr > 0) _availableBalance = initialInr;
  }

  Future<void> _fetchInitialData() async {
    setState(() => _isLoading = true);
    
    // Attempt brute-force direct fetch first
    try {
      // Trigger socket requests to force immediate balance update
      SocketService.requestWalletSummary();
      SocketService.requestWalletBalance();

      final bruteForce = await WalletService.getINRBalance();
      if (bruteForce['success'] == true && mounted) {
        setState(() {
          _availableBalance = bruteForce['inrBalance'] ?? 0.0;
        });
        debugPrint('WithdrawINRScreen: Brute-force INR fetch successful: $_availableBalance');
      }
    } catch (e) {
      debugPrint('WithdrawINRScreen: Brute-force error: $e');
    }

    await Future.wait([
      _fetchBankAccounts(),
      UnifiedWalletService.refreshAllBalances(),
    ]);

    if (mounted) {
      setState(() {
        // Prefer service value if > 0, else fallback to local
        _availableBalance = UnifiedWalletService.totalINRBalance > 0 
            ? UnifiedWalletService.totalINRBalance 
            : _availableBalance;
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchBankAccounts() async {
    try {
      final result = await WalletService.getINRBankDetails();
      if (result['success'] == true && result['data'] != null) {
        final rawData = result['data'];
        List<Map<String, dynamic>> accounts = [];
        
        void parseItem(dynamic item) {
          if (item is Map) {
            final map = Map<String, dynamic>.from(item);
            // Only support bank accounts for withdrawals
            if (map.containsKey('accountNumber') || map.containsKey('bankName')) {
              accounts.add(map);
            }
          }
        }

        if (rawData is List) {
          for (var item in rawData) parseItem(item);
        } else if (rawData is Map) {
          if (rawData['docs'] is List) {
            for (var item in rawData['docs']) parseItem(item);
          } else {
            parseItem(rawData);
          }
        }
        
        setState(() => _bankAccounts = accounts);
      }
    } catch (e) {
      debugPrint('Error fetching bank accounts: $e');
    }
  }

  void _navigateToStep(int step) {
    setState(() => _currentStep = step);
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
    );
  }

  void _nextStep() {
    if (_currentStep == 0) {
      if (_selectedBankAccount == null) {
        NotificationService.showError(context: context, title: 'Selection Required', message: 'Please select a bank account');
        return;
      }
      
      // Check KYC and profile requirements before proceeding from bank selection
      if (!_validateUserRequirements()) {
        return;
      }
      
      _navigateToStep(1);
    } else if (_currentStep == 1) {
      final amount = double.tryParse(_amountController.text);
      if (amount == null || amount <= 0) {
        NotificationService.showError(context: context, title: 'Invalid Amount', message: 'Please enter a valid amount');
        return;
      }
      if (amount > _availableBalance) {
        NotificationService.showError(context: context, title: 'Insufficient Balance', message: 'Amount exceeds available balance');
        return;
      }
      _navigateToStep(2);
    } else if (_currentStep == 2) {
      _sendOTP();
    } else if (_currentStep == 3) {
      _submitWithdrawal();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      _navigateToStep(_currentStep - 1);
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _sendOTP() async {
    setState(() => _isSendingOTP = true);
    debugPrint('[_sendOTP] Starting OTP request...');
    
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF84BD00),
          strokeWidth: 3,
        ),
      ),
    );
    
    try {
      final result = await WalletService.sendINROTP();
      debugPrint('[_sendOTP] Result: $result');
      
      // Close loading dialog
      Navigator.pop(context);
      
      if (result['success'] == true) {
        NotificationService.showSuccess(context: context, title: 'OTP Sent', message: result['message'] ?? 'Verification code sent to your email');
        // Small delay to let user see the success message
        await Future.delayed(const Duration(milliseconds: 500));
        _navigateToStep(3);
      } else {
        NotificationService.showError(context: context, title: 'OTP Failed', message: result['error'] ?? 'Could not send OTP');
      }
    } catch (e, stackTrace) {
      // Close loading dialog if showing
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      debugPrint('[_sendOTP] Error: $e');
      debugPrint('[_sendOTP] StackTrace: $stackTrace');
      NotificationService.showError(context: context, title: 'Error', message: 'Failed to send OTP: $e');
    } finally {
      setState(() => _isSendingOTP = false);
    }
  }

  Future<void> _submitWithdrawal() async {
    if (_amountController.text.isEmpty) {
      NotificationService.showError(context: context, title: 'Invalid Amount', message: 'Please enter amount');
      return;
    }

    if (_otpController.text.length < 4) {
      NotificationService.showError(context: context, title: 'Verification Required', message: 'Please enter the valid OTP');
      return;
    }

    setState(() => _isSubmittingWithdrawal = true);
    try {
      final amount = double.tryParse(_amountController.text) ?? 0.0;
      if (amount <= 0) {
        NotificationService.showError(context: context, title: 'Invalid Amount', message: 'Please enter a valid amount');
        return;
      }
      
      // Get payment method ID (bank account ID)
      final paymentMethodId = _selectedBankAccount?['_id']?.toString() ?? _selectedBankAccount?['id']?.toString();
      debugPrint('[_submitWithdrawal] paymentMethodId: $paymentMethodId');
      
      final result = await WalletService.submitINRWithdrawal(
        otp: _otpController.text,
        amount: amount,
        withdrawType: 1, // Always use bank transfer
        paymentMethodId: paymentMethodId,
        accountHolderName: _selectedBankAccount?['accountHolderName']?.toString() ?? _selectedBankAccount?['holderName']?.toString() ?? '',
        accountNumber: _selectedBankAccount?['accountNumber']?.toString() ?? '',
        ifscCode: _selectedBankAccount?['ifscCode']?.toString() ?? '',
        bankName: _selectedBankAccount?['bankName']?.toString() ?? _selectedBankAccount?['Name']?.toString() ?? '',
        upiId: null, // No UPI for bank withdrawals
      );

      if (result['success'] == true) {
        if (mounted) {
          _showSuccessDialog();
        }
      } else {
        if (mounted) {
          NotificationService.showError(context: context, title: 'Withdrawal Failed', message: result['error'] ?? 'Something went wrong');
        }
      }
    } finally {
      setState(() => _isSubmittingWithdrawal = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF84BD00).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: Color(0xFF84BD00), size: 80),
            ),
            const SizedBox(height: 24),
            const Text('Withdrawal Initiated', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text('Your request for ₹${_amountController.text} has been received and is being processed.', 
              textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Dialog
                  Navigator.pop(context); // Screen
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF84BD00),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Great!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showWithdrawalHistory() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => _WithdrawalHistorySheet(
          scrollController: scrollController,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Force sync if local balance is 0 but service has value
    if (_availableBalance == 0.0 && UnifiedWalletService.totalINRBalance > 0) {
      _availableBalance = UnifiedWalletService.totalINRBalance;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: _prevStep,
        ),
        title: Text(_getStepTitle(), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.history, color: Colors.white, size: 22),
            onPressed: _showWithdrawalHistory,
            tooltip: 'Withdrawal History',
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF84BD00)))
        : Column(
            children: [
              _buildProgressHeader(),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildBankSelectionStep(),
                    _buildAmountEntryStep(),
                    _buildReviewStep(),
                    _buildOTPVerificationStep(),
                  ],
                ),
              ),
              _buildBottomAction(),
            ],
          ),
    );
  }

  String _getStepTitle() {
    switch (_currentStep) {
      case 0: return 'Select Method';
      case 1: return 'Withdraw Amount';
      case 2: return 'Review Request';
      case 3: return 'Verification';
      default: return 'Withdraw INR';
    }
  }

  Widget _buildProgressHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(30, 10, 30, 20),
      child: Row(
        children: [
          _buildStepNode(0, 'Source'),
          _buildStepLink(0),
          _buildStepNode(1, 'Amount'),
          _buildStepLink(1),
          _buildStepNode(2, 'Review'),
          _buildStepLink(2),
          _buildStepNode(3, 'Verify'),
        ],
      ),
    );
  }

  Widget _buildStepNode(int step, String label) {
    bool isCompleted = _currentStep > step;
    bool isActive = _currentStep == step;
    
    return Column(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: isCompleted ? const Color(0xFF84BD00) : (isActive ? Colors.white : Colors.white10),
            shape: BoxShape.circle,
            boxShadow: isActive ? [
              BoxShadow(color: Colors.white.withOpacity(0.2), blurRadius: 10, spreadRadius: 1)
            ] : null,
          ),
          child: Center(
            child: isCompleted 
              ? const Icon(Icons.check, color: Colors.black, size: 14)
              : Text('${step + 1}', style: TextStyle(
                  color: isActive ? Colors.black : Colors.white24, 
                  fontSize: 10, 
                  fontWeight: FontWeight.bold
                )),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: TextStyle(
          color: isActive ? Colors.white : (isCompleted ? Colors.white70 : Colors.white24), 
          fontSize: 9,
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal
        )),
      ],
    );
  }

  Widget _buildStepLink(int step) {
    bool isCompleted = _currentStep > step;
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 15),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(1),
          color: isCompleted ? const Color(0xFF84BD00) : Colors.white10,
        ),
      ),
    );
  }

  Widget _buildBankSelectionStep() {
    if (_bankAccounts.isEmpty) {
      return _buildEmptyState();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Withdraw to account', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              // History Button
              GestureDetector(
                onTap: _showWithdrawalHistory,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF84BD00).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF84BD00).withOpacity(0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.history, color: Color(0xFF84BD00), size: 14),
                      SizedBox(width: 4),
                      Text(
                        'History',
                        style: TextStyle(color: Color(0xFF84BD00), fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text('Select an approved destination for your funds.', style: TextStyle(color: Colors.white54, fontSize: 14)),
          const SizedBox(height: 32),
          
          // KYC Requirement Warning
          if (!_isKYCCompleted())
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 24),
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

          ..._bankAccounts.map((account) {
            final status = account['status'] is int ? account['status'] : int.tryParse(account['status']?.toString() ?? '1');
            final isSelected = _selectedBankAccount?['_id'] == account['_id'];
            final isApproved = status == 2;

            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: InkWell(
                onTap: isApproved ? () => setState(() => _selectedBankAccount = account) : null,
                borderRadius: BorderRadius.circular(16),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF84BD00).withOpacity(0.05) : const Color(0xFF1E1E20),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF84BD00) : (isApproved ? Colors.white.withOpacity(0.05) : Colors.red.withOpacity(0.2)),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF84BD00).withOpacity(0.1) : const Color(0xFF2A2A2C),
                          borderRadius: BorderRadius.circular(12)
                        ),
                        child: Icon(
                          Icons.account_balance, 
                          color: isApproved ? const Color(0xFF84BD00) : Colors.white24,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              account['bankName'] ?? 'Bank', 
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '•••• ${account['accountNumber']?.toString().substring((account['accountNumber']?.toString().length ?? 4) - 4)}', 
                              style: TextStyle(color: isSelected ? Colors.white70 : Colors.white38, fontSize: 13)
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        const Icon(Icons.check_circle, color: Color(0xFF84BD00), size: 24)
                      else
                        _getStatusIndicator(status),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 12),
          _buildAddAction(),
        ],
      ),
    );
  }

  Widget _getStatusIndicator(int? status) {
    String text;
    Color color;
    switch (status) {
      case 1: text = 'Pending'; color = Colors.orange; break;
      case 2: text = 'Approved'; color = const Color(0xFF84BD00); break;
      case 3: text = 'Rejected'; color = Colors.red; break;
      default: text = 'Unknown'; color = Colors.grey;
    }
    
    if (status == 2) return const Icon(Icons.arrow_forward_ios, color: Colors.white12, size: 14);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildAddAction() {
    // Check if user already has an approved or pending bank account
    final hasExistingAccount = _bankAccounts.any((account) {
      final status = account['status'] is int ? account['status'] : int.tryParse(account['status']?.toString() ?? '1');
      return status == 1 || status == 2; // Pending or Approved
    });

    if (hasExistingAccount) {
      // Show message that only one account is allowed
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.orange.withOpacity(0.1),
          border: Border.all(color: Colors.orange.withOpacity(0.3)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline, color: Colors.orange, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'You can only add one bank account. Contact support to change your account.',
                style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => AddInrBankScreen())).then((_) => _fetchBankAccounts()),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05), style: BorderStyle.solid),
          color: Colors.white.withOpacity(0.02),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline, color: Color(0xFF84BD00), size: 20),
            SizedBox(width: 10),
            Text('Add Bank Account', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), shape: BoxShape.circle),
              child: const Icon(Icons.account_balance_wallet_outlined, color: Colors.white10, size: 80),
            ),
            const SizedBox(height: 32),
            const Text('No Payment Method', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text('Please add a bank account and wait for approval to start withdrawing your funds.', 
              textAlign: TextAlign.center, style: TextStyle(color: Colors.white38, fontSize: 14, height: 1.5)),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => AddInrBankScreen())).then((_) => _fetchBankAccounts()),
                icon: const Icon(Icons.add),
                label: const Text('Add Bank Account'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF84BD00), 
                  foregroundColor: Colors.black, 
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Note: You can only add one bank account.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountEntryStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Withdrawal amount', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 32),
          
          // Balance Info
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E20),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('Available Balance', style: TextStyle(color: Colors.white38, fontSize: 13)),
                        const SizedBox(width: 8),
                        if (_isLoading)
                          const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF84BD00)))
                        else
                          GestureDetector(
                            onTap: () async {
                              setState(() => _isLoading = true);
                              await UnifiedWalletService.refreshAllBalances();
                              // Also request via socket directly
                              SocketService.requestWalletSummary();
                              SocketService.requestWalletBalance();
                              if (mounted) {
                                setState(() {
                                  _availableBalance = UnifiedWalletService.totalINRBalance;
                                  _isLoading = false;
                                });
                              }
                            },
                            child: const Icon(Icons.refresh, color: Color(0xFF84BD00), size: 14),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _availableBalance > 0 
                          ? '₹${_availableBalance.toStringAsFixed(2)}' 
                          : (_isLoading ? 'Updating...' : '₹0.00'), 
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF84BD00).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('INR', style: TextStyle(color: Color(0xFF84BD00), fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 40),
          const Text('Amount to withdraw', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(height: 12),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
            onChanged: (v) => setState(() {}),
            decoration: InputDecoration(
              prefixText: '₹ ',
              prefixStyle: const TextStyle(color: Color(0xFF84BD00), fontSize: 32),
              hintText: '0.00',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.05)),
              border: InputBorder.none,
              suffixIcon: TextButton(
                onPressed: () {
                  setState(() => _amountController.text = _availableBalance.toStringAsFixed(2));
                },
                style: TextButton.styleFrom(backgroundColor: const Color(0xFF84BD00).withOpacity(0.1), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                child: const Text('MAX', style: TextStyle(color: Color(0xFF84BD00), fontWeight: FontWeight.bold)),
              ),
            ),
          ),
          const Divider(color: Colors.white10, thickness: 1),
          
          const SizedBox(height: 32),
          // Destination Preview
          _buildSummaryItem(
            icon: Icons.account_balance_outlined,
            title: 'Destination',
            value: _selectedBankAccount?['bankName'] ?? 'Selected Account',
            subtitle: _selectedBankAccount?['accountNumber'] != null ? '•••• ${_selectedBankAccount?['accountNumber'].toString().substring((_selectedBankAccount?['accountNumber'].toString().length ?? 4) - 4)}' : null,
          ),
        ],
      ),
    );
  }

  Widget _buildReviewStep() {
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    final fee = 0.0; // Assume 0 fee for now or fetch from service
    final total = amount - fee;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Review Details', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Verify your withdrawal request before proceeding.', style: TextStyle(color: Colors.white54, fontSize: 14)),
          const SizedBox(height: 32),
          
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E20),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                _buildReviewRow('Withdrawal Amount', '₹${amount.toStringAsFixed(2)}', isBold: true),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Divider(color: Colors.white10),
                ),
                _buildReviewRow('Withdrawal Fee', '₹${fee.toStringAsFixed(2)}'),
                const SizedBox(height: 12),
                _buildReviewRow('Total to Receive', '₹${total.toStringAsFixed(2)}', color: const Color(0xFF84BD00), isBold: true),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E20),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Recipient Details', style: TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
                const SizedBox(height: 20),
                _buildReviewDetail('Account Holder', _selectedBankAccount?['accountHolderName'] ?? _selectedBankAccount?['holderName'] ?? 'N/A'),
                const SizedBox(height: 16),
                _buildReviewDetail('Bank Name', _selectedBankAccount?['bankName'] ?? _selectedBankAccount?['Name'] ?? 'N/A'),
                const SizedBox(height: 16),
                _buildReviewDetail('Account Number', _selectedBankAccount?['accountNumber'] ?? 'N/A'),
                const SizedBox(height: 16),
                _buildReviewDetail('IFSC Code', _selectedBankAccount?['ifscCode'] ?? 'N/A'),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withOpacity(0.2)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue, size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Funds usually arrive within 24-48 working hours.',
                    style: TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOTPVerificationStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Security Verify', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 32),
          Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF84BD00).withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.shield_outlined, color: Color(0xFF84BD00), size: 64),
            ),
          ),
          const SizedBox(height: 32),
          const Text('Enter 6-digit OTP', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('We\'ve sent a verification code to your registered email address. Please enter it below to authorize this withdrawal.', 
            style: TextStyle(color: Colors.white54, fontSize: 14, height: 1.5)),
          const SizedBox(height: 32),
          
          TextField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 12),
            decoration: InputDecoration(
              counterText: '',
              filled: true,
              fillColor: const Color(0xFF1E1E20),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              hintText: '••••••',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.05), letterSpacing: 12),
            ),
          ),
          
          const SizedBox(height: 24),
          Center(
            child: TextButton(
              onPressed: _isSendingOTP ? null : _sendOTP,
              child: Text(
                _isSendingOTP ? 'Sending...' : 'Resend Code', 
                style: const TextStyle(color: Color(0xFF84BD00), fontWeight: FontWeight.bold)
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewRow(String label, String value, {Color? color, bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 14)),
        Text(value, style: TextStyle(
          color: color ?? Colors.white, 
          fontSize: 16, 
          fontWeight: isBold ? FontWeight.bold : FontWeight.w500
        )),
      ],
    );
  }

  Widget _buildReviewDetail(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(label, style: const TextStyle(color: Colors.white38, fontSize: 13)),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }

  Widget _buildSummaryItem({required IconData icon, required String title, required String value, String? subtitle}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1E1E20), borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Icon(icon, color: Colors.white38, size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 12)),
                ],
              ],
            ),
          ),
          IconButton(
            onPressed: () => _navigateToStep(0),
            icon: const Icon(Icons.edit_outlined, color: Color(0xFF84BD00), size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomAction() {
    bool isButtonEnabled = true;
    if (_currentStep == 0 && _selectedBankAccount == null) isButtonEnabled = false;
    if (_currentStep == 1 && (_amountController.text.isEmpty || (double.tryParse(_amountController.text) ?? 0) <= 0)) isButtonEnabled = false;

    String buttonText;
    switch (_currentStep) {
      case 0: buttonText = 'Continue'; break;
      case 1: buttonText = 'Review Request'; break;
      case 2: buttonText = 'Confirm & Send OTP'; break;
      case 3: buttonText = 'Verify & Withdraw'; break;
      default: buttonText = 'Continue';
    }

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        child: SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: isButtonEnabled && !_isSendingOTP && !_isSubmittingWithdrawal ? _nextStep : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF84BD00),
              disabledBackgroundColor: Colors.white.withOpacity(0.05),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: _isSendingOTP || _isSubmittingWithdrawal
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
              : Text(buttonText, style: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }
}

// Withdrawal History Bottom Sheet Widget
class _WithdrawalHistoryBottomSheet extends StatefulWidget {
  @override
  State<_WithdrawalHistoryBottomSheet> createState() => _WithdrawalHistoryBottomSheetState();
}

class _WithdrawalHistoryBottomSheetState extends State<_WithdrawalHistoryBottomSheet> {
  List<Map<String, dynamic>> _history = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    try {
      // Using new API: GET /wallet/v1/wallet/transactions?type=2&category=inr
      final result = await WalletService.getINRWithdrawalHistoryNew(page: 1, limit: 50);
      if (result['success'] == true) {
        final data = result['data'];
        List<Map<String, dynamic>> history = [];
        
        if (data is List) {
          history = List<Map<String, dynamic>>.from(data);
        } else if (data is Map && data['withdrawals'] is List) {
          history = List<Map<String, dynamic>>.from(data['withdrawals']);
        } else if (data is Map && data['data'] is List) {
          history = List<Map<String, dynamic>>.from(data['data']);
        }
        
        setState(() {
          _history = history;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = result['error'] ?? 'Failed to fetch history';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  String _formatStatus(String? status) {
    if (status == null) return 'Unknown';
    switch (status.toLowerCase()) {
      case 'completed':
      case 'success':
      case 'approved':
      case 'processing':  // Changed: Processing now shows as Completed
        return 'Completed';
      case 'pending':
        return 'Pending';
      case 'failed':
      case 'rejected':
      case 'cancelled':
        return 'Failed';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Completed':
        return const Color(0xFF84BD00);
      case 'Failed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'Completed':
        return Icons.check_circle;
      case 'Failed':
        return Icons.error;
      default:
        return Icons.help;
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'Unknown';
    try {
      final date = DateTime.tryParse(dateStr);
      if (date == null) return dateStr;
      // Convert to IST (UTC+5:30)
      final istDate = date.toUtc().add(const Duration(hours: 5, minutes: 30));
      return DateFormat('dd MMM yyyy, hh:mm a').format(istDate);
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Withdrawal History',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF84BD00),
                    ),
                  )
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline, color: Colors.red, size: 48),
                              const SizedBox(height: 16),
                              Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white70),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _fetchHistory,
                                icon: const Icon(Icons.refresh, size: 18),
                                label: const Text('Retry'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF84BD00),
                                  foregroundColor: Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _history.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(40),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(24),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.05),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.history,
                                      color: Colors.white24,
                                      size: 48,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  const Text(
                                    'No Withdrawals Yet',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Your INR withdrawal history will appear here.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _fetchHistory,
                            color: const Color(0xFF84BD00),
                            backgroundColor: const Color(0xFF2A2A2C),
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _history.length,
                              itemBuilder: (context, index) {
                                final item = _history[index];
                                final status = _formatStatus(item['status']?.toString());
                                final statusColor = _getStatusColor(status);
                                final statusIcon = _getStatusIcon(status);
                                final isUPI = item['upiId'] != null && item['upiId'].toString().isNotEmpty;
                                final amount = (item['amount'] as num?)?.toDouble() ?? 0.0;
                                final bankName = item['bankName']?.toString() ?? item['bank']?.toString() ?? 'Bank';
                                final accountNumber = item['accountNumber']?.toString() ?? '';
                                final upiId = item['upiId']?.toString() ?? '';
                                final createdAt = item['createdAt']?.toString() ?? item['date']?.toString();

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2A2A2C),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            '₹${amount.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: statusColor.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(statusIcon, color: statusColor, size: 12),
                                                const SizedBox(width: 4),
                                                Text(
                                                  status,
                                                  style: TextStyle(
                                                    color: statusColor,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF84BD00).withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Icon(
                                              isUPI ? Icons.vibration : Icons.account_balance,
                                              color: const Color(0xFF84BD00),
                                              size: 16,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  isUPI ? 'UPI Payment' : 'Bank Transfer',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  isUPI
                                                      ? upiId
                                                      : '$bankName ${accountNumber.isNotEmpty ? '••••${accountNumber.substring(accountNumber.length > 4 ? accountNumber.length - 4 : 0)}' : ''}',
                                                  style: TextStyle(
                                                    color: Colors.white.withOpacity(0.5),
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        _formatDate(createdAt),
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.4),
                                          fontSize: 11,
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
      ),
    );
  }

  /// Normalize status from API (handles both int and string values)
  int _normalizeStatus(dynamic status) {
    if (status == null) return 1;
    if (status is int) return status;
    if (status is String) {
      switch (status.toLowerCase()) {
        case 'pending':
        case 'processing':
          return 1;
        case 'completed':
        case 'success':
        case 'approved':
          return 2;
        case 'failed':
        case 'rejected':
        case 'cancelled':
          return 3;
        default:
          return 1;
      }
    }
    return 1;
  }

  /// Format date to IST timezone
  String _formatISTDateTime(dynamic createdAt) {
    if (createdAt == null) return 'Unknown';
    try {
      DateTime date;
      final createdAtStr = createdAt.toString();

      // Try parsing as ISO string first
      date = DateTime.tryParse(createdAtStr) ?? DateTime.now();

      // If parsing failed, try parsing as Unix timestamp
      if (date == DateTime.now() && createdAtStr.isNotEmpty) {
        final timestamp = int.tryParse(createdAtStr);
        if (timestamp != null) {
          date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
        }
      }

      // Convert to IST (UTC+5:30)
      final istDate = date.toUtc().add(const Duration(hours: 5, minutes: 30));

      // Format with AM/PM
      return DateFormat('dd MMM yyyy, hh:mm a').format(istDate);
    } catch (e) {
      return createdAt.toString();
    }
  }

  /// Capitalize status string for display
  String _capitalizeStatus(String status) {
    if (status.isEmpty) return 'Unknown';
    return status[0].toUpperCase() + status.substring(1).toLowerCase();
  }

  /// Get color based on exact API status
  Color _getStatusColorFromApi(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'success':
      case 'approved':
        return const Color(0xFF84BD00);
      case 'pending':
        return Colors.orange;
      case 'processing':
        return Colors.blue;
      case 'failed':
      case 'rejected':
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

// INR Withdrawal History Bottom Sheet
class _WithdrawalHistorySheet extends StatefulWidget {
  final ScrollController scrollController;

  const _WithdrawalHistorySheet({required this.scrollController});

  @override
  State<_WithdrawalHistorySheet> createState() => _WithdrawalHistorySheetState();
}

class _WithdrawalHistorySheetState extends State<_WithdrawalHistorySheet> {
  bool _isLoading = true;
  List<dynamic> _withdrawals = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchWithdrawalHistory();
  }

  Future<void> _fetchWithdrawalHistory() async {
    try {
      final result = await WalletService.getINRWithdrawalHistoryNew(limit: 20);
      if (mounted) {
        setState(() {
          if (result['success'] == true && result['data'] != null) {
            final data = result['data'];
            if (data is List) {
              _withdrawals = data;
            } else if (data is Map && data['result'] != null) {
              _withdrawals = data['result'];
            } else if (data is Map && data['transactions'] != null) {
              _withdrawals = data['transactions'];
            }
          } else {
            _error = result['error'] ?? 'No withdrawal history found';
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load history: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1))),
            ),
            child: Row(
              children: [
                const Icon(Icons.history, color: Color(0xFF84BD00), size: 24),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'INR Withdrawal History',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF84BD00)),
                  )
                : _error != null && _withdrawals.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.history, color: Colors.white24, size: 48),
                            const SizedBox(height: 16),
                            Text(
                              _error!,
                              style: const TextStyle(color: Colors.white54, fontSize: 14),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _fetchWithdrawalHistory,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF84BD00),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: const Text('Retry', style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: widget.scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _withdrawals.length,
                        itemBuilder: (context, index) {
                          final withdrawal = _withdrawals[index];
                          return _buildWithdrawalItem(withdrawal);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  /// Normalize status from API (handles both int and string values)
  int _normalizeStatus(dynamic status) {
    if (status == null) return 1;
    if (status is int) return status;
    if (status is String) {
      switch (status.toLowerCase()) {
        case 'pending':
        case 'processing':
          return 1;
        case 'completed':
        case 'success':
        case 'approved':
          return 2;
        case 'failed':
        case 'rejected':
        case 'cancelled':
          return 3;
        default:
          return 1;
      }
    }
    return 1;
  }

  Widget _buildWithdrawalItem(Map<String, dynamic> withdrawal) {
    final amount = double.tryParse(withdrawal['amount']?.toString() ?? '0') ?? 0;
    final rawStatus = withdrawal['status'] ?? 1;
    // Handle both integer and string status values from API
    final status = _normalizeStatus(rawStatus);
    final withdrawType = withdrawal['withdrawType'] ?? withdrawal['withdraw_type'] ?? 1;
    final isUPI = withdrawType == 2;
    final createdAt = withdrawal['createdAt'] ?? withdrawal['created_at'];
    final formattedDate = _formatISTDateTime(createdAt);

    final bankDetails = withdrawal['bankDetails'] ?? withdrawal['withdrawDetails'] ?? withdrawal['bank_details'] ?? {};
    final bankName = bankDetails['bankName']?.toString() ?? bankDetails['bank_name']?.toString() ?? '';
    final accountHolder = bankDetails['accountHolderName']?.toString() ?? bankDetails['account_holder_name']?.toString() ?? '';
    final accountNumber = bankDetails['accountNumber']?.toString() ?? bankDetails['account_number']?.toString() ?? '';
    final upiId = withdrawal['upiId']?.toString() ?? withdrawal['upi_id']?.toString() ?? '';

    // Show exact status from API with proper formatting
    // API Status: 1-Pending, 2-Approved, 3-Cancelled, 4-Rejected, 5-Completed
    String statusText;
    Color statusColor;
    // Try to parse as int first (handles both int and string numbers like "2")
    final statusInt = int.tryParse(rawStatus?.toString() ?? '1');
    if (statusInt != null) {
      switch (statusInt) {
        case 1:
          statusText = 'Pending';
          statusColor = Colors.orange;
          break;
        case 2:
          statusText = 'Approved';
          statusColor = const Color(0xFF84BD00);
          break;
        case 3:
          statusText = 'Cancelled';
          statusColor = Colors.white54;
          break;
        case 4:
          statusText = 'Rejected';
          statusColor = Colors.red;
          break;
        case 5:
          statusText = 'Completed';
          statusColor = const Color(0xFF84BD00);
          break;
        default:
          statusText = 'Unknown';
          statusColor = Colors.grey;
      }
    } else {
      // Handle string status like "completed", "pending", etc.
      final rawStatusStr = rawStatus?.toString() ?? 'pending';
      statusText = _capitalizeStatus(rawStatusStr);
      statusColor = _getStatusColorFromApi(rawStatusStr);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isUPI ? Colors.purple.withOpacity(0.2) : Colors.blue.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isUPI ? Icons.account_balance_wallet : Icons.account_balance,
                  color: isUPI ? Colors.purple : Colors.blue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '₹${amount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formattedDate,
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (accountHolder.isNotEmpty)
                  Text(
                    'Holder: $accountHolder',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                if (isUPI && upiId.isNotEmpty)
                  Text(
                    'UPI: $upiId',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  )
                else if (bankName.isNotEmpty) ...[
                  Text(
                    'Bank: $bankName',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  if (accountNumber.isNotEmpty)
                    Text(
                      'A/C: XXXX${accountNumber.substring(accountNumber.length > 4 ? accountNumber.length - 4 : 0)}',
                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Format date to IST timezone
  String _formatISTDateTime(dynamic createdAt) {
    if (createdAt == null) return 'Unknown';
    try {
      DateTime date;
      final createdAtStr = createdAt.toString();

      // Try parsing as ISO string first
      date = DateTime.tryParse(createdAtStr) ?? DateTime.now();

      // If parsing failed, try parsing as Unix timestamp
      if (date == DateTime.now() && createdAtStr.isNotEmpty) {
        final timestamp = int.tryParse(createdAtStr);
        if (timestamp != null) {
          date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
        }
      }

      // Convert to IST (UTC+5:30)
      final istDate = date.toUtc().add(const Duration(hours: 5, minutes: 30));

      // Format with AM/PM
      return DateFormat('dd MMM yyyy, hh:mm a').format(istDate);
    } catch (e) {
      return createdAt.toString();
    }
  }

  /// Capitalize status string for display
  String _capitalizeStatus(String status) {
    if (status.isEmpty) return 'Unknown';
    return status[0].toUpperCase() + status.substring(1).toLowerCase();
  }

  /// Get color based on exact API status
  Color _getStatusColorFromApi(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'success':
      case 'approved':
        return const Color(0xFF84BD00);
      case 'pending':
        return Colors.orange;
      case 'processing':
        return Colors.blue;
      case 'failed':
      case 'rejected':
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
