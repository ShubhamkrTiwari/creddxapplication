import 'package:flutter/material.dart';
import '../services/p2p_service.dart';

class PaymentMethodSelectionScreen extends StatefulWidget {
  const PaymentMethodSelectionScreen({super.key});

  @override
  State<PaymentMethodSelectionScreen> createState() => _PaymentMethodSelectionScreenState();
}

class _PaymentMethodSelectionScreenState extends State<PaymentMethodSelectionScreen> {
  String _selectedMethod = 'Bank';
  bool _showAddDetails = false;
  bool _isEligible = false;
  bool _isCheckingEligibility = true;
  String? _eligibilityMessage;
  final _bankNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _accountHolderController = TextEditingController();
  final _ifscController = TextEditingController();
  final _upiIdController = TextEditingController();
  final _upiHolderNameController = TextEditingController();
  bool _isSaving = false;
  bool _isVerifying = false;

  @override
  void initState() {
    super.initState();
    _checkEligibility();
  }

  Future<void> _checkEligibility() async {
    setState(() => _isCheckingEligibility = true);
    
    try {
      final result = await P2PService.checkPaymentMethodEligibility();
      
      if (mounted) {
        setState(() {
          _isEligible = result['eligible'] ?? false;
          _eligibilityMessage = result['message'] ?? 'Unable to check eligibility';
          _isCheckingEligibility = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isEligible = false;
          _eligibilityMessage = 'Error checking eligibility: $e';
          _isCheckingEligibility = false;
        });
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
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Payment Method',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add Payment Method',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            // Eligibility Status
            _buildEligibilityStatus(),
            
            if (_isEligible) ...[
              const SizedBox(height: 24),
              
              const Text(
                'Select Payment Method',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              
              // Payment Method Selection
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _buildPaymentOption('Bank', Icons.account_balance),
                    _buildPaymentOption('UPI', Icons.account_balance_wallet),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Payment Details Form
              _buildPaymentDetailsForm(),
              
              const SizedBox(height: 32),
              
              // Action Buttons
              if (_showAddDetails) ...[
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _savePaymentDetails,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF84BD00),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isSaving
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Save Details',
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isVerifying ? null : _confirmPayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF84BD00),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isVerifying
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Add Payment Method',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEligibilityStatus() {
    if (_isCheckingEligibility) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          children: [
            CircularProgressIndicator(color: Color(0xFF84BD00), strokeWidth: 2),
            SizedBox(width: 16),
            Text(
              'Checking eligibility...',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      );
    }

    if (!_isEligible) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF2C2C2E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red),
                SizedBox(width: 12),
                Text(
                  'Not Eligible',
                  style: TextStyle(color: Colors.red, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _eligibilityMessage ?? 'You are not currently eligible to add a payment method.',
              style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 14),
            ),
            const SizedBox(height: 16),
            const Text(
              'Requirements:',
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            _buildRequirementItem('✓ Complete KYC verification'),
            _buildRequirementItem('✓ Have at least 1 successful trade'),
            _buildRequirementItem('✓ Account age: 7+ days'),
            _buildRequirementItem('✓ No active disputes'),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF84BD00).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF84BD00)),
      ),
      child: const Row(
        children: [
          Icon(Icons.check_circle, color: Color(0xFF84BD00)),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'You are eligible to add a payment method',
              style: TextStyle(color: Color(0xFF84BD00), fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequirementItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 13),
      ),
    );
  }

  Widget _buildPaymentOption(String method, IconData icon) {
    final isSelected = _selectedMethod == method;
    return ListTile(
      leading: Icon(icon, color: isSelected ? const Color(0xFF84BD00) : const Color(0xFF8E8E93)),
      title: Text(
        method,
        style: TextStyle(
          color: isSelected ? const Color(0xFF84BD00) : Colors.white,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: isSelected
          ? const Icon(Icons.check_circle, color: Color(0xFF84BD00))
          : null,
      onTap: () {
        setState(() {
          _selectedMethod = method;
          _showAddDetails = true;
        });
      },
    );
  }

  Widget _buildPaymentDetailsForm() {
    if (!_showAddDetails) return const SizedBox.shrink();

    if (_selectedMethod == 'Bank') {
      return _buildBankDetailsForm();
    } else {
      return _buildUpiDetailsForm();
    }
  }

  Widget _buildBankDetailsForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Bank Details',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          
          _buildTextField('Bank Name', _bankNameController),
          const SizedBox(height: 16),
          _buildTextField('Account Number', _accountNumberController, keyboardType: TextInputType.number),
          const SizedBox(height: 16),
          _buildTextField('Account Holder Name', _accountHolderController),
          const SizedBox(height: 16),
          _buildTextField('IFSC Code', _ifscController),
        ],
      ),
    );
  }

  Widget _buildUpiDetailsForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'UPI Details',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          
          _buildTextField('UPI ID', _upiIdController),
          const SizedBox(height: 16),
          _buildTextField('Account Holder Name', _upiHolderNameController),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {TextInputType? keyboardType}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType ?? TextInputType.text,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Enter $label',
            hintStyle: const TextStyle(color: Color(0xFF8E8E93)),
            filled: true,
            fillColor: const Color(0xFF2C2C2E),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
      ],
    );
  }

  Future<void> _savePaymentDetails() async {
    if (_selectedMethod == 'Bank') {
      if (_bankNameController.text.isEmpty || 
          _accountNumberController.text.isEmpty || 
          _accountHolderController.text.isEmpty || 
          _ifscController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please fill all bank details'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    } else {
      if (_upiIdController.text.isEmpty || _upiHolderNameController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please fill all UPI details'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    setState(() => _isSaving = true);

    try {
      final paymentData = _selectedMethod == 'Bank' 
          ? {
              'type': 'Bank',
              'bankName': _bankNameController.text,
              'accountNumber': _accountNumberController.text,
              'accountHolder': _accountHolderController.text,
              'ifsc': _ifscController.text,
            }
          : {
              'type': 'UPI',
              'upiId': _upiIdController.text,
              'accountHolder': _upiHolderNameController.text,
            };

      // Save payment details
      final result = await P2PService.savePaymentMethod(paymentData);
      
      if (result) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment details saved successfully'),
            backgroundColor: Color(0xFF84BD00),
          ),
        );
        setState(() => _showAddDetails = false);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save payment details'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _confirmPayment() async {
    setState(() => _isVerifying = true);

    try {
      // Verify payment details are saved
      final result = await P2PService.verifyPaymentMethod(_selectedMethod);
      
      if (result) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment verified and saved successfully'),
            backgroundColor: Color(0xFF84BD00),
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment verification failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isVerifying = false);
    }
  }

  @override
  void dispose() {
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _accountHolderController.dispose();
    _ifscController.dispose();
    _upiIdController.dispose();
    _upiHolderNameController.dispose();
    super.dispose();
  }
}
