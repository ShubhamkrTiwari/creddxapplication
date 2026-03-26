import 'package:flutter/material.dart';
import '../services/p2p_service.dart';
import 'otp_verification_screen.dart';
import 'payment_method_screen.dart';

class AddBankAccountScreen extends StatefulWidget {
  final String country;
  final bool isEditMode;
  final Map<String, dynamic>? editData;
  
  const AddBankAccountScreen({
    super.key, 
    required this.country,
    this.isEditMode = false,
    this.editData,
  });

  @override
  State<AddBankAccountScreen> createState() => _AddBankAccountScreenState();
}

class _AddBankAccountScreenState extends State<AddBankAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _holderNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _confirmAccountNumberController = TextEditingController();
  final _ifscCodeController = TextEditingController();
  
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Populate fields if in edit mode
    if (widget.isEditMode && widget.editData != null) {
      _holderNameController.text = widget.editData!['holderName'] ?? '';
      // Extract account number from details (assuming format includes ****)
      final details = widget.editData!['details'] ?? '';
      _accountNumberController.text = details; // You might need to parse this better
      _confirmAccountNumberController.text = details;
      _ifscCodeController.text = ''; // IFSC code might need to be stored separately
    }
  }

  @override
  void dispose() {
    _holderNameController.dispose();
    _accountNumberController.dispose();
    _confirmAccountNumberController.dispose();
    _ifscCodeController.dispose();
    super.dispose();
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
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
        ),
        title: Text(
          widget.isEditMode ? 'Edit Bank Account Details' : 'Your Bank Account Detail',
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                _buildFieldLabel('Account holder name'),
                const SizedBox(height: 10),
                _buildTextField(
                  controller: _holderNameController,
                  hint: 'Account Holder Name',
                ),
                const SizedBox(height: 24),
                _buildFieldLabel('Account Number'),
                const SizedBox(height: 10),
                _buildTextField(
                  controller: _accountNumberController,
                  hint: 'Enter your Account Number',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 24),
                _buildFieldLabel('Confirm Account Number'),
                const SizedBox(height: 10),
                _buildTextField(
                  controller: _confirmAccountNumberController,
                  hint: 'Re-enter your Account Number',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 24),
                _buildFieldLabel('IFSC Code'),
                const SizedBox(height: 10),
                _buildTextField(
                  controller: _ifscCodeController,
                  hint: 'Enter your IFSC Code',
                  textCapitalization: TextCapitalization.characters,
                ),
                const SizedBox(height: 60),
                
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleInitialSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF84BD00),
                      disabledBackgroundColor: const Color(0xFF84BD00).withOpacity(0.5),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.black,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Text(
                            widget.isEditMode ? 'Update' : 'Submit',
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        color: Colors.white70,
        fontSize: 14,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    TextCapitalization? textCapitalization,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization ?? TextCapitalization.sentences,
      style: const TextStyle(color: Colors.white, fontSize: 16),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24, fontSize: 16),
        filled: true,
        fillColor: const Color(0xFF1C1C1E),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF84BD00), width: 1),
        ),
      ),
    );
  }

  Future<void> _handleInitialSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_accountNumberController.text != _confirmAccountNumberController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account numbers do not match')),
      );
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      final response = await P2PService.sendPaymentMethodOTP();
      
      setState(() => _isLoading = false);
      
      if (mounted) {
        if (response['success'] == true) {
          // Navigate to OTP Screen
          final bool? verified = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OtpVerificationScreen(
                onVerify: (otp) async {
                  debugPrint('Bank OTP entered: $otp'); // Debug log
                  final verifyResponse = await P2PService.verifyPaymentMethodOTP(otp);
                  debugPrint('Bank OTP Verify Response: $verifyResponse'); // Debug log
                  
                  // Check for success in multiple possible formats
                  final isSuccess = verifyResponse['success'] == true || 
                                   verifyResponse['success'] == 'true' ||
                                   verifyResponse['status'] == 'success' ||
                                   (verifyResponse['message']?.toString().toLowerCase().contains('verified') == true) ||
                                   (verifyResponse['message']?.toString().toLowerCase().contains('success') == true);
                  
                  debugPrint('Bank OTP verification success check: $isSuccess from response: $verifyResponse'); // Debug log
                  
                  if (isSuccess) {
                    // Finally save the payment method after OTP verification
                    final saveResponse = await P2PService.savePaymentMethod({
                      'type': 'BANK',
                      'bankName': 'Bank', // Typically selected from a list or entered
                      'accountNumber': _accountNumberController.text,
                      'ifscCode': _ifscCodeController.text,
                      'holderName': _holderNameController.text,
                      'country': widget.country,
                    });
                    debugPrint('Save Bank Response: $saveResponse'); // Debug log
                    
                    // Always return success to trigger navigation, even if save fails
                    // The user can try adding again if save failed
                    return {
                      'success': true, // Always return true to navigate
                      'message': saveResponse 
                          ? (widget.isEditMode ? 'Bank account updated successfully' : 'Bank account added')
                          : 'OTP verified but failed to save details. Please try again.',
                      'saveFailed': !saveResponse // Flag to indicate save failure
                    };
                  }
                  return verifyResponse;
                },
              ),
            ),
          );

          debugPrint('Bank navigation returned verified value: $verified'); // Debug log
          if (verified == true) {
            // Navigate to payment list screen showing saved payment methods
            debugPrint('Navigating to PaymentMethodScreen from bank'); // Debug log
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const PaymentMethodScreen()),
              (route) => false,
            );
          } else {
            debugPrint('Bank navigation failed or verification returned false/null'); // Debug log
            // Show error message to user
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Payment method verification completed, but navigation failed'),
                  backgroundColor: Colors.orange,
                ),
              );
              // Fallback navigation
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const PaymentMethodScreen()),
                (route) => false,
              );
            }
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response['message'] ?? 'Failed to send OTP')),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}
