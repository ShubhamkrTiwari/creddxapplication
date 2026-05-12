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

class BotInrWithdrawScreen extends StatefulWidget {
  const BotInrWithdrawScreen({super.key});

  @override
  State<BotInrWithdrawScreen> createState() => _BotInrWithdrawScreenState();
}

class _BotInrWithdrawScreenState extends State<BotInrWithdrawScreen> with KYCUnlockMixin {
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
        final newInr = UnifiedWalletService.totalINRBalance;
        setState(() {
          _availableBalance = newInr;
        });
      }
    });
    final initialInr = UnifiedWalletService.totalINRBalance;
    if (initialInr > 0) _availableBalance = initialInr;
  }

  Future<void> _fetchInitialData() async {
    setState(() => _isLoading = true);
    
    try {
      SocketService.requestWalletSummary();
      SocketService.requestWalletBalance();

      final bruteForce = await WalletService.getINRBalance();
      if (bruteForce['success'] == true && mounted) {
        setState(() {
          _availableBalance = bruteForce['inrBalance'] ?? 0.0;
        });
      }
    } catch (e) {
      debugPrint('BotInrWithdrawScreen: Error fetching balance: $e');
    }

    await Future.wait([
      _fetchBankAccounts(),
      UnifiedWalletService.refreshAllBalances(),
    ]);

    if (mounted) {
      setState(() {
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
      if (!_validateUserRequirements()) return;
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
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF84BD00), strokeWidth: 3),
      ),
    );
    
    try {
      final result = await WalletService.sendINROTP();
      Navigator.pop(context);
      
      if (result['success'] == true) {
        NotificationService.showSuccess(context: context, title: 'OTP Sent', message: result['message'] ?? 'Verification code sent to your email');
        await Future.delayed(const Duration(milliseconds: 500));
        _navigateToStep(3);
      } else {
        NotificationService.showError(context: context, title: 'OTP Failed', message: result['error'] ?? 'Could not send OTP');
      }
    } catch (e) {
      if (Navigator.canPop(context)) Navigator.pop(context);
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
      final paymentMethodId = _selectedBankAccount?['_id']?.toString() ?? _selectedBankAccount?['id']?.toString();
      
      final result = await WalletService.submitINRWithdrawal(
        otp: _otpController.text,
        amount: amount,
        withdrawType: 1,
        paymentMethodId: paymentMethodId,
        accountHolderName: _selectedBankAccount?['accountHolderName']?.toString() ?? _selectedBankAccount?['holderName']?.toString() ?? '',
        accountNumber: _selectedBankAccount?['accountNumber']?.toString() ?? '',
        ifscCode: _selectedBankAccount?['ifscCode']?.toString() ?? '',
        bankName: _selectedBankAccount?['bankName']?.toString() ?? _selectedBankAccount?['Name']?.toString() ?? '',
        upiId: null,
      );

      if (result['success'] == true) {
        if (mounted) _showSuccessDialog();
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
            Text('Your request for ₹${_amountController.text} from Bot wallet has been received and is being processed.', 
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
      default: return 'Bot Withdraw INR';
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
        color: isCompleted ? const Color(0xFF84BD00) : Colors.white10,
      ),
    );
  }

  Widget _buildBankSelectionStep() {
    if (_bankAccounts.isEmpty) return _buildEmptyState();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Withdraw to account', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Select an approved destination for your funds.', style: TextStyle(color: Colors.white54, fontSize: 14)),
          const SizedBox(height: 32),
          
          if (!_isKYCCompleted())
            _buildKYCWarning(),

          ..._bankAccounts.map((account) {
            final status = account['status'] is int ? account['status'] : int.tryParse(account['status']?.toString() ?? '1');
            final isSelected = _selectedBankAccount?['_id'] == account['_id'];
            final isApproved = status == 2;

            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: InkWell(
                onTap: isApproved ? () => setState(() => _selectedBankAccount = account) : null,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF84BD00).withOpacity(0.05) : const Color(0xFF1E1E20),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF84BD00) : Colors.white.withOpacity(0.05),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.account_balance, color: Color(0xFF84BD00), size: 24),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(account['bankName'] ?? 'Bank', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 4),
                            Text('•••• ${account['accountNumber']?.toString().substring((account['accountNumber']?.toString().length ?? 4) - 4)}', 
                              style: const TextStyle(color: Colors.white38, fontSize: 13)),
                          ],
                        ),
                      ),
                      if (isSelected) const Icon(Icons.check_circle, color: Color(0xFF84BD00), size: 24),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildKYCWarning() {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          const Row(
            children: [
              Icon(Icons.verified_user_outlined, color: Colors.orange, size: 24),
              SizedBox(width: 16),
              Text('KYC Verification Required', style: TextStyle(color: Colors.orange, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const UpdateProfileScreen())),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Complete KYC Now', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.account_balance_wallet_outlined, color: Colors.white10, size: 80),
          const SizedBox(height: 32),
          const Text('No Payment Method', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => AddInrBankScreen())).then((_) => _fetchBankAccounts()),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF84BD00)),
            child: const Text('Add Bank Account', style: TextStyle(color: Colors.black)),
          ),
        ],
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
          Text('Available: ₹${_availableBalance.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFF84BD00), fontSize: 16)),
          const SizedBox(height: 12),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              prefixText: '₹ ',
              prefixStyle: const TextStyle(color: Color(0xFF84BD00), fontSize: 32),
              hintText: '0.00',
              border: InputBorder.none,
              suffixIcon: TextButton(
                onPressed: () => setState(() => _amountController.text = _availableBalance.toStringAsFixed(2)),
                child: const Text('MAX', style: TextStyle(color: Color(0xFF84BD00))),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewStep() {
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Review Details', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 32),
          _buildReviewRow('Withdrawal Amount', '₹${amount.toStringAsFixed(2)}', isBold: true),
          const SizedBox(height: 24),
          _buildReviewDetail('Account Holder', _selectedBankAccount?['accountHolderName'] ?? 'N/A'),
          _buildReviewDetail('Bank Name', _selectedBankAccount?['bankName'] ?? 'N/A'),
          _buildReviewDetail('Account Number', _selectedBankAccount?['accountNumber'] ?? 'N/A'),
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
          TextField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 12),
            decoration: const InputDecoration(hintText: '••••••', border: InputBorder.none),
          ),
          Center(
            child: TextButton(
              onPressed: _isSendingOTP ? null : _sendOTP,
              child: const Text('Resend Code', style: TextStyle(color: Color(0xFF84BD00))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 14)),
        Text(value, style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: isBold ? FontWeight.bold : FontWeight.w500)),
      ],
    );
  }

  Widget _buildReviewDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text(label, style: const TextStyle(color: Colors.white38, fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(color: Colors.white70, fontSize: 14))),
        ],
      ),
    );
  }

  Widget _buildBottomAction() {
    String buttonText = 'Continue';
    if (_currentStep == 2) buttonText = 'Confirm & Send OTP';
    if (_currentStep == 3) buttonText = 'Verify & Withdraw';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: _isSubmittingWithdrawal ? null : _nextStep,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF84BD00)),
            child: _isSubmittingWithdrawal 
              ? const CircularProgressIndicator(color: Colors.black) 
              : Text(buttonText, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }
}

class _WithdrawalHistorySheet extends StatefulWidget {
  final ScrollController scrollController;
  const _WithdrawalHistorySheet({required this.scrollController});

  @override
  State<_WithdrawalHistorySheet> createState() => _WithdrawalHistorySheetState();
}

class _WithdrawalHistorySheetState extends State<_WithdrawalHistorySheet> {
  bool _isLoading = true;
  List<dynamic> _withdrawals = [];

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    try {
      final result = await WalletService.getINRWithdrawalHistoryNew();
      if (mounted) {
        setState(() {
          _withdrawals = result['data'] ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1A1A1A),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Withdrawal History', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF84BD00)))
              : ListView.builder(
                  controller: widget.scrollController,
                  itemCount: _withdrawals.length,
                  itemBuilder: (context, index) {
                    final item = _withdrawals[index];
                    return ListTile(
                      title: Text('₹${item['amount']}', style: const TextStyle(color: Colors.white)),
                      subtitle: Text(item['createdAt'] ?? '', style: const TextStyle(color: Colors.white54)),
                      trailing: Text(item['status']?.toString() ?? 'Pending', style: const TextStyle(color: Color(0xFF84BD00))),
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }
}
