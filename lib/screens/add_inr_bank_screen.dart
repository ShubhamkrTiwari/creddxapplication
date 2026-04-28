import 'package:flutter/material.dart';
import '../services/wallet_service.dart';
import '../services/notification_service.dart';

class AddInrBankScreen extends StatefulWidget {
  final bool isEditMode;
  final Map<String, dynamic>? editData;
  
  const AddInrBankScreen({
    super.key,
    this.isEditMode = false,
    this.editData,
  });

  @override
  State<AddInrBankScreen> createState() => _AddInrBankScreenState();
}

class _AddInrBankScreenState extends State<AddInrBankScreen> {
  final _formKey = GlobalKey<FormState>();

  final _holderNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _confirmAccountNumberController = TextEditingController();
  final _ifscCodeController = TextEditingController();
  final _bankNameController = TextEditingController();
  
  bool _isLoading = false;
  bool _isCheckingExisting = true;
  bool _hasExistingAccount = false;

  @override
  void initState() {
    super.initState();

    if (widget.isEditMode && widget.editData != null) {
      _holderNameController.text = widget.editData!['accountHolderName'] ?? widget.editData!['holderName'] ?? '';
      _bankNameController.text = widget.editData!['bankName'] ?? widget.editData!['Name'] ?? '';
      _accountNumberController.text = widget.editData!['accountNumber'] ?? '';
      _confirmAccountNumberController.text = widget.editData!['accountNumber'] ?? '';
      _ifscCodeController.text = widget.editData!['ifscCode'] ?? '';

      // In edit mode, no need to check
      setState(() => _isCheckingExisting = false);
    } else {
      // Check for existing accounts in add mode
      _checkExistingAccounts();
    }
  }

  Future<void> _checkExistingAccounts() async {
    try {
      final result = await WalletService.getINRBankDetails();
      if (result['success'] == true && result['data'] != null) {
        final rawData = result['data'];
        List<Map<String, dynamic>> accounts = [];
        
        void parseItem(dynamic item) {
          if (item is Map) {
            final map = Map<String, dynamic>.from(item);
            if (map.containsKey('accountNumber') || map.containsKey('bankName') || map.containsKey('upiId')) {
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

        // Check if any account is pending (1) or approved (2)
        final hasActiveAccount = accounts.any((account) {
          final status = account['status'] is int ? account['status'] : int.tryParse(account['status']?.toString() ?? '1');
          return status == 1 || status == 2;
        });

        setState(() {
          _hasExistingAccount = hasActiveAccount;
          _isCheckingExisting = false;
        });
      } else {
        setState(() => _isCheckingExisting = false);
      }
    } catch (e) {
      debugPrint('Error checking existing accounts: $e');
      setState(() => _isCheckingExisting = false);
    }
  }

  @override
  void dispose() {
    _holderNameController.dispose();
    _accountNumberController.dispose();
    _confirmAccountNumberController.dispose();
    _ifscCodeController.dispose();
    _bankNameController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_accountNumberController.text != _confirmAccountNumberController.text) {
      NotificationService.showError(context: context, title: 'Validation Error', message: 'Account numbers do not match');
      return;
    }

    setState(() => _isLoading = true);

    try {
      Map<String, dynamic> response;

      if (widget.isEditMode && widget.editData != null) {
        final id = widget.editData!['_id']?.toString() ?? widget.editData!['id']?.toString() ?? '';
        response = await WalletService.editINRBankAccount(
          id: id,
          accountHolderName: _holderNameController.text,
          accountNumber: _accountNumberController.text,
          ifscCode: _ifscCodeController.text,
          bankName: _bankNameController.text,
          upiId: null,
          type: 1, // Bank account type
        );
      } else {
        response = await WalletService.addINRBankAccount(
          accountHolderName: _holderNameController.text,
          accountNumber: _accountNumberController.text,
          ifscCode: _ifscCodeController.text,
          bankName: _bankNameController.text,
          upiId: null,
          type: 1, // Bank account type
        );
      }
      
      if (response['success'] == true) {
        if (mounted) {
          NotificationService.showSuccess(
            context: context, 
            title: 'Success', 
            message: widget.isEditMode ? 'Account updated' : 'Account added successfully'
          );
          Navigator.pop(context, true);
        }
      } else {
        if (mounted) {
          NotificationService.showError(
            context: context, 
            title: 'Failed', 
            message: response['error'] ?? response['message'] ?? 'Failed to save details'
          );
        }
      }
    } catch (e) {
      if (mounted) {
        NotificationService.showError(context: context, title: 'Error', message: e.toString());
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading while checking for existing accounts
    if (_isCheckingExisting) {
      return Scaffold(
        backgroundColor: const Color(0xFF0D0D0D),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          ),
          title: const Text(
            'Add New Account',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFF84BD00)),
        ),
      );
    }

    // Show restriction if user already has an account (in add mode)
    if (!widget.isEditMode && _hasExistingAccount) {
      return Scaffold(
        backgroundColor: const Color(0xFF0D0D0D),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          ),
          title: const Text(
            'Add New Account',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.account_balance,
                    color: Colors.orange,
                    size: 64,
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Account Limit Reached',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'You can only add one bank account. If you need to change your account details, please contact support.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Go Back'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF84BD00),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
        ),
        title: Text(
          widget.isEditMode ? 'Edit Bank Account' : 'Add Bank Account',
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('Account Information'),
              const SizedBox(height: 20),
              _buildFieldLabel('Account Holder Name'),
              _buildTextField(
                controller: _holderNameController,
                hint: 'As per bank records',
                icon: Icons.person_outline,
                validator: (v) => v!.isEmpty ? 'Name is required' : null,
              ),
              const SizedBox(height: 20),
              _buildFieldLabel('Bank Name'),
              _buildTextField(
                controller: _bankNameController,
                hint: 'e.g. HDFC Bank',
                icon: Icons.account_balance_outlined,
                validator: (v) => v!.isEmpty ? 'Bank name is required' : null,
              ),
              const SizedBox(height: 20),
              _buildFieldLabel('Account Number'),
              _buildTextField(
                controller: _accountNumberController,
                hint: 'Enter your account number',
                icon: Icons.numbers,
                keyboardType: TextInputType.number,
                validator: (v) => v!.isEmpty ? 'Account number is required' : null,
              ),
              const SizedBox(height: 20),
              _buildFieldLabel('Confirm Account Number'),
              _buildTextField(
                controller: _confirmAccountNumberController,
                hint: 'Re-enter account number',
                icon: Icons.check_circle_outline,
                keyboardType: TextInputType.number,
                validator: (v) => v!.isEmpty ? 'Please confirm account number' : null,
              ),
              const SizedBox(height: 20),
              _buildFieldLabel('IFSC Code'),
              _buildTextField(
                controller: _ifscCodeController,
                hint: 'e.g. HDFC0001234',
                icon: Icons.code,
                textCapitalization: TextCapitalization.characters,
                validator: (v) => v!.isEmpty ? 'IFSC code is required' : null,
              ),
              const SizedBox(height: 40),
              _buildSubmitButton(),
              const SizedBox(height: 20),
              _buildSecurityNote(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white38, fontSize: 12),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      validator: validator,
      style: const TextStyle(color: Colors.white, fontSize: 16),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white10, fontSize: 15),
        prefixIcon: Icon(icon, color: Colors.white24, size: 20),
        filled: true,
        fillColor: const Color(0xFF1E1E20),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF84BD00), width: 1),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.red.withOpacity(0.5), width: 1),
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleSubmit,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF84BD00),
          disabledBackgroundColor: Colors.white.withOpacity(0.05),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
            : Text(
                widget.isEditMode ? 'Update Account' : 'Save Account',
                style: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold),
              ),
      ),
    );
  }

  Widget _buildSecurityNote() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E20),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.security, color: Color(0xFF84BD00), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Secure Information', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  'Your payment details are encrypted and securely stored. Approval may take up to 24 hours.',
                  style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

