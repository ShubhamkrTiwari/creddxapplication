import 'package:flutter/material.dart';
import '../services/wallet_service.dart';
import '../services/notification_service.dart';
import 'add_bank_account_screen.dart';
import 'add_inr_bank_screen.dart';

class WithdrawINRScreen extends StatefulWidget {
  const WithdrawINRScreen({super.key});

  @override
  State<WithdrawINRScreen> createState() => _WithdrawINRScreenState();
}

class _WithdrawINRScreenState extends State<WithdrawINRScreen> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _bankAccounts = []; // All saved bank accounts
  Map<String, dynamic>? _selectedBankAccount; // Currently selected for withdrawal
  int? _bankStatus; // 1 = Pending, 2 = Approved, 3 = Rejected
  String? _bankId;
  
  // Available balance for withdrawal
  double _availableBalance = 0.0;
  
  // Controllers for withdrawal
  final _amountController = TextEditingController();
  final _otpController = TextEditingController();
  bool _isSendingOTP = false;
  bool _isSubmittingWithdrawal = false;

  @override
  void initState() {
    super.initState();
    _fetchBankAccount();
  }

  Future<void> _fetchBankAccount() async {
    setState(() => _isLoading = true);
    
    try {
      final result = await WalletService.getINRBankDetails();
      
      if (result['success'] == true && result['data'] != null) {
        final rawData = result['data'];
        debugPrint('WithdrawINRScreen: Bank data received: $rawData');
        
        List<Map<String, dynamic>> accounts = [];
        
        void parseItem(dynamic item) {
          if (item is Map) {
            final map = Map<String, dynamic>.from(item);
            // Be very permissive about keys
            if (map.containsKey('accountNumber') || 
                map.containsKey('bankName') || 
                map.containsKey('Name') ||
                map.containsKey('account_number') ||
                map.containsKey('bank_name')) {
              accounts.add(map);
            }
          }
        }

        if (rawData is List) {
          for (var item in rawData) {
            parseItem(item);
          }
        } else if (rawData is Map) {
          if (rawData['docs'] is List) {
            for (var item in rawData['docs']) parseItem(item);
          } else if (rawData['data'] is List) {
            for (var item in rawData['data']) parseItem(item);
          } else if (rawData['result'] is List) {
            for (var item in rawData['result']) parseItem(item);
          } else {
            parseItem(rawData);
          }
        }
        
        debugPrint('WithdrawINRScreen: Parsed ${accounts.length} accounts');
        
        // Filter only approved accounts (status = 2) or show all if specifically needed
        final approvedAccounts = accounts.where((acc) {
          final status = acc['status'] is int 
              ? acc['status'] 
              : int.tryParse(acc['status']?.toString() ?? '1');
          return status == 2;
        }).toList();
        
        setState(() {
          _bankAccounts = accounts;
          // Select first approved account by default, or the first account if none are approved
          _selectedBankAccount = approvedAccounts.isNotEmpty 
              ? approvedAccounts.first 
              : (accounts.isNotEmpty ? accounts.first : null);
          
          if (_selectedBankAccount != null) {
            _bankStatus = _selectedBankAccount!['status'] is int 
                ? _selectedBankAccount!['status'] 
                : int.tryParse(_selectedBankAccount!['status']?.toString() ?? '1');
            _bankId = _selectedBankAccount?['_id']?.toString() ?? _selectedBankAccount?['id']?.toString();
          } else {
            _bankStatus = null;
            _bankId = null;
          }
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['error'] ?? 'Failed to fetch bank details')),
          );
        }
        setState(() {
          _bankAccounts = [];
          _selectedBankAccount = null;
          _bankStatus = null;
          _bankId = null;
        });
      }
    } catch (e) {
      debugPrint('Error fetching bank account: $e');
      setState(() {
        _bankAccounts = [];
        _selectedBankAccount = null;
        _bankStatus = null;
        _bankId = null;
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Select a specific bank account for withdrawal
  void _selectBankAccount(Map<String, dynamic> account) {
    setState(() {
      _selectedBankAccount = account;
      _bankId = account['_id']?.toString() ?? account['id']?.toString();
    });
  }

  // Get status text based on status code
  String _getStatusText(int? status) {
    switch (status) {
      case 1:
        return 'Pending';
      case 2:
        return 'Approved';
      case 3:
        return 'Rejected';
      default:
        return 'Unknown';
    }
  }

  // Get status color based on status code
  Color _getStatusColor(int? status) {
    switch (status) {
      case 1:
        return const Color(0xFFFFC107); // Yellow for pending
      case 2:
        return const Color(0xFF00C087); // Green for approved
      case 3:
        return const Color(0xFFFF3B30); // Red for rejected
      default:
        return Colors.grey;
    }
  }

  // Send OTP for withdrawal
  Future<void> _sendOTP() async {
    setState(() => _isSendingOTP = true);
    
    try {
      final result = await WalletService.sendINROTP();
      
      if (result['success'] == true) {
        if (mounted) {
          NotificationService.showSuccess(
            context: context,
            title: 'OTP Sent',
            message: result['message'] ?? 'OTP has been sent to your registered mobile/email',
          );
        }
      } else {
        if (mounted) {
          NotificationService.showError(
            context: context,
            title: 'Failed to Send OTP',
            message: result['error'] ?? 'Could not send OTP. Please try again.',
          );
        }
      }
    } catch (e) {
      debugPrint('Error sending OTP: $e');
      if (mounted) {
        NotificationService.showError(
          context: context,
          title: 'Error',
          message: 'Failed to send OTP. Please check your connection.',
        );
      }
    } finally {
      setState(() => _isSendingOTP = false);
    }
  }

  // Submit withdrawal request
  Future<void> _submitWithdrawal() async {
    if (_amountController.text.isEmpty) {
      NotificationService.showError(
        context: context,
        title: 'Invalid Amount',
        message: 'Please enter withdrawal amount',
      );
      return;
    }

    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      NotificationService.showError(
        context: context,
        title: 'Invalid Amount',
        message: 'Please enter a valid withdrawal amount',
      );
      return;
    }

    if (_otpController.text.isEmpty) {
      NotificationService.showError(
        context: context,
        title: 'OTP Required',
        message: 'Please enter the OTP sent to your device',
      );
      return;
    }

    if (_bankId == null) {
      NotificationService.showError(
        context: context,
        title: 'Error',
        message: 'Bank account not found',
      );
      return;
    }

    setState(() => _isSubmittingWithdrawal = true);

    try {
      final result = await WalletService.submitINRWithdrawal(
        otp: _otpController.text,
        amount: amount,
        withdrawType: 1, // 1 for BANK
        accountHolderName: _selectedBankAccount?['accountHolderName']?.toString() ??
                          _selectedBankAccount?['accountHolder']?.toString() ??
                          _selectedBankAccount?['holderName']?.toString() ?? '',
        accountNumber: _selectedBankAccount?['accountNumber']?.toString() ?? '',
        ifscCode: _selectedBankAccount?['ifscCode']?.toString() ??
                 _selectedBankAccount?['ifsc']?.toString() ?? '',
        bankName: _selectedBankAccount?['bankName']?.toString() ??
                 _selectedBankAccount?['Name']?.toString() ??
                 _selectedBankAccount?['name']?.toString() ?? '',
      );

      if (result['success'] == true) {
        if (mounted) {
          NotificationService.showSuccess(
            context: context,
            title: 'Withdrawal Submitted',
            message: result['message'] ?? 'Your withdrawal request has been submitted successfully',
          );
          // Clear controllers
          _amountController.clear();
          _otpController.clear();
          // Refresh bank details
          _fetchBankAccount();
        }
      } else {
        if (mounted) {
          NotificationService.showError(
            context: context,
            title: 'Withdrawal Failed',
            message: result['error'] ?? 'Failed to submit withdrawal request',
          );
        }
      }
    } catch (e) {
      debugPrint('Error submitting withdrawal: $e');
      if (mounted) {
        NotificationService.showError(
          context: context,
          title: 'Error',
          message: 'Failed to submit withdrawal. Please try again.',
        );
      }
    } finally {
      setState(() => _isSubmittingWithdrawal = false);
    }
  }

  // Show withdrawal dialog for approved bank accounts
  void _showWithdrawalDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E20),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Withdraw INR',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Selected Bank Account
                  if (_selectedBankAccount != null) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A2A2C),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF84BD00).withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Withdrawal Account',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                              // Show change button if multiple approved accounts
                              if (_bankAccounts.where((acc) {
                                final status = acc['status'] is int
                                    ? acc['status']
                                    : int.tryParse(acc['status']?.toString() ?? '1');
                                return status == 2;
                              }).length > 1)
                                GestureDetector(
                                  onTap: () => _showBankSelectionSheet(setModalState),
                                  child: const Text(
                                    'Change',
                                    style: TextStyle(
                                      color: Color(0xFF84BD00),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E1E20),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.account_balance,
                                  color: Color(0xFF84BD00),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _selectedBankAccount!['bankName']?.toString() ?? 'Bank',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '•••• ${_selectedBankAccount!['accountNumber']?.toString().substring(_selectedBankAccount!['accountNumber'].toString().length - 4)}',
                                      style: const TextStyle(
                                        color: Colors.white54,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Amount Input
                  const Text(
                    'Amount (INR)',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2A2C),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: TextField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      decoration: const InputDecoration(
                        hintText: 'Enter amount',
                        hintStyle: TextStyle(color: Colors.white38),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Send OTP Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSendingOTP ? null : _sendOTP,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF84BD00),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        disabledBackgroundColor: Colors.grey.shade800,
                      ),
                      child: _isSendingOTP
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Send OTP',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // OTP Input
                  const Text(
                    'Enter OTP',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2A2C),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: TextField(
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      decoration: const InputDecoration(
                        hintText: 'Enter 6-digit OTP',
                        hintStyle: TextStyle(color: Colors.white38),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 16),
                        counterText: '',
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSubmittingWithdrawal ? null : _submitWithdrawal,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF84BD00),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        disabledBackgroundColor: Colors.grey.shade800,
                      ),
                      child: _isSubmittingWithdrawal
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Withdraw Now',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _navigateToAddBankAccount() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AddInrBankScreen(),
      ),
    ).then((_) => _fetchBankAccount()); // Refresh after returning
  }

  void _navigateToEditBankAccount(Map<String, dynamic> account) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddInrBankScreen(
          isEditMode: true,
          editData: account,
        ),
      ),
    ).then((_) => _fetchBankAccount()); // Refresh after returning
  }

  // Show bank selection sheet for multiple accounts
  void _showBankSelectionSheet(StateSetter setModalState) {
    final approvedAccounts = _bankAccounts.where((acc) {
      final status = acc['status'] is int
          ? acc['status']
          : int.tryParse(acc['status']?.toString() ?? '1');
      return status == 2;
    }).toList();

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
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Select Bank Account',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ...approvedAccounts.map((account) {
                final isSelected = _selectedBankAccount?['_id']?.toString() == account['_id']?.toString() ||
                    _selectedBankAccount?['id']?.toString() == account['id']?.toString();
                final accountNum = account['accountNumber']?.toString() ?? '';
                final last4 = accountNum.length > 4 ? accountNum.substring(accountNum.length - 4) : accountNum;

                return GestureDetector(
                  onTap: () {
                    _selectBankAccount(account);
                    Navigator.pop(context);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF84BD00).withOpacity(0.15) : const Color(0xFF2A2A2C),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF84BD00) : Colors.white10,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF84BD00).withOpacity(0.2) : const Color(0xFF1E1E20),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.account_balance,
                            color: isSelected ? const Color(0xFF84BD00) : Colors.white54,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                account['bankName']?.toString() ?? 'Bank',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '•••• $last4',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          const Icon(
                            Icons.check_circle,
                            color: Color(0xFF84BD00),
                            size: 24,
                          ),
                      ],
                    ),
                  ),
                );
              }).toList(),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF84BD00)))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with back button
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E1E20),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Title
                    const Text(
                      'Withdraw INR',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Subtitle
                    const Text(
                      'Select your approved bank account to proceed with the withdrawal.',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Warning Box
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFC107).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFFFC107).withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(
                            color: Color(0xFFFFC107),
                            fontSize: 13,
                            height: 1.5,
                          ),
                          children: [
                            const TextSpan(
                              text:
                                  'Your bank account must match the name on your KYC documents. Withdrawals to unverified or third-party accounts are not permitted. Each account requires admin approval before use — this may take up to 24 hours. To change an already-approved account, contact ',
                            ),
                            TextSpan(
                              text: 'support@creddx.com',
                              style: const TextStyle(
                                decoration: TextDecoration.underline,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Bank Account Card or Empty State
                    if (_bankAccounts.isEmpty) ...[
                      _buildEmptyState(),
                    ] else ...[
                      ..._bankAccounts.map((account) => Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: _buildBankAccountCard(account),
                      )),
                    ],

                    const SizedBox(height: 20),

                    // Add Bank Account Button
                    _buildAddBankAccountButton(),

                    const SizedBox(height: 40),

                    // FAQ Section
                    _buildFAQSection(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white10,
          width: 1,
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2C),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.account_balance_outlined,
              color: Colors.white38,
              size: 28,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Bank Account Added',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add your bank account to start withdrawing funds securely. Admin approval is required before your first withdrawal.',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBankAccountCard(Map<String, dynamic> account) {
    final status = account['status'] is int
        ? account['status']
        : int.tryParse(account['status']?.toString() ?? '1');
    final accountId = account['_id']?.toString() ?? account['id']?.toString();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF84BD00).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2C),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.account_balance,
                  color: Color(0xFF84BD00),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account['bankName'] ?? account['bank_name'] ?? account['Name'] ?? account['name'] ?? 'Bank Name',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Builder(builder: (context) {
                      final accNum = (account['accountNumber'] ?? account['account_number'] ?? '').toString();
                      final last4 = accNum.length > 4 ? accNum.substring(accNum.length - 4) : accNum;
                      return Text(
                        accNum.isNotEmpty ? '•••• $last4' : 'No Account Number',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 14,
                        ),
                      );
                    }),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getStatusColor(status).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _getStatusText(status),
                  style: TextStyle(
                    color: _getStatusColor(status),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 20),
          _buildInfoRow('Account Holder', account['accountHolderName'] ?? account['account_holder_name'] ?? account['accountHolder'] ?? account['holderName'] ?? 'Name'),
          const SizedBox(height: 12),
          _buildInfoRow('IFSC Code', account['ifscCode'] ?? account['ifsc_code'] ?? account['ifsc'] ?? 'IFSC'),
          const SizedBox(height: 20),
          if (status == 1) // Pending
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFC107).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFC107).withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.access_time, color: Color(0xFFFFC107), size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Bank account is under verification. Withdrawal will be enabled after admin approval.',
                      style: TextStyle(
                        color: Color(0xFFFFC107),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else if (status == 3) // Rejected
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _navigateToEditBankAccount(account),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF3B30),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Edit Bank Details',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )
          else if (status == 2) // Approved
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  setState(() => _selectedBankAccount = account);
                  _showWithdrawalDialog();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF84BD00),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Withdraw Now',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 13,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildAddBankAccountButton() {
    // Only show Add Bank button when there's no selected bank account
    if (_selectedBankAccount != null) return const SizedBox.shrink();
    
    return GestureDetector(
      onTap: _navigateToAddBankAccount,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E20),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white10,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.add,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Add Bank Account',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Receive withdrawals directly via NEFT / RTGS / IMPS. One bank account per user. Must match your KYC name and be approved by admin before use.',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFAQSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white10,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.help_outline,
            color: Colors.white54,
            size: 20,
          ),
          const SizedBox(width: 8),
          const Text(
            'FAQs',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _otpController.dispose();
    super.dispose();
  }
}
