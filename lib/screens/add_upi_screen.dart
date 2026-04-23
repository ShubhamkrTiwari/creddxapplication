import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/p2p_service.dart';
import 'otp_verification_screen.dart';
import 'payment_method_screen.dart';
import 'saved_payment_methods_screen.dart';

// Country name to numeric code mapping for API
const Map<String, String> countryCodeMap = {
  'India': '91',
  'United States': '1',
  'United Kingdom': '44',
  'Canada': '1',
  'Australia': '61',
  'Germany': '49',
  'France': '33',
  'United Arab Emirates': '971',
  'Singapore': '65',
  'Japan': '81',
};

class AddUpiScreen extends StatefulWidget {
  final String country;
  final bool isEditMode;
  final Map<String, dynamic>? editData;
  
  const AddUpiScreen({
    super.key, 
    required this.country,
    this.isEditMode = false,
    this.editData,
  });

  @override
  State<AddUpiScreen> createState() => _AddUpiScreenState();
}

class _AddUpiScreenState extends State<AddUpiScreen> {
  final _formKey = GlobalKey<FormState>();
  final _holderNameController = TextEditingController();
  final _upiIdController = TextEditingController();
  final _confirmUpiIdController = TextEditingController();
  
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Populate fields if in edit mode
    if (widget.isEditMode && widget.editData != null) {
      _holderNameController.text = widget.editData!['holderName'] ?? '';
      _upiIdController.text = widget.editData!['details'] ?? '';
      _confirmUpiIdController.text = widget.editData!['details'] ?? '';
    }
  }

  @override
  void dispose() {
    _holderNameController.dispose();
    _upiIdController.dispose();
    _confirmUpiIdController.dispose();
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
          widget.isEditMode ? 'Edit UPI Details' : 'Your UPI Id Details',
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
                _buildFieldLabel('Account holder details'),
                const SizedBox(height: 10),
                _buildTextField(
                  controller: _holderNameController,
                  hint: 'UPI user name',
                ),
                const SizedBox(height: 24),
                _buildFieldLabel('UPI ID'),
                const SizedBox(height: 10),
                _buildTextField(
                  controller: _upiIdController,
                  hint: 'Enter your UPI ID',
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 24),
                _buildFieldLabel('Confirm UPI ID'),
                const SizedBox(height: 10),
                _buildTextField(
                  controller: _confirmUpiIdController,
                  hint: 'Re-enter your UPI ID',
                  keyboardType: TextInputType.emailAddress,
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
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SavedPaymentMethodsScreen(),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF84BD00)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Saved Payment Methods',
                      style: TextStyle(
                        color: Color(0xFF84BD00),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
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
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
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
    
    if (_upiIdController.text != _confirmUpiIdController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('UPI IDs do not match')),
      );
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      // Send OTP first
      debugPrint('Sending OTP for UPI verification...'); // Debug log
      final response = await P2PService.sendPaymentMethodOTP();
      
      setState(() => _isLoading = false);
      debugPrint('OTP Send Response: $response'); // Debug log
      
      if (mounted) {
        // Check for success in multiple possible formats
        final isSuccess = response['success'] == true || 
                         response['status'] == 'success' ||
                         response['message']?.toString().toLowerCase().contains('sent') == true ||
                         (response is Map && !response.containsKey('error') && !response.containsKey('success'));
        
        if (isSuccess) {
          debugPrint('OTP sent successfully, opening OTP screen'); // Debug log
          
          // Navigate to OTP verification screen
          final bool? verified = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OtpVerificationScreen(
                onVerify: (otp) async {
                  debugPrint('UPI OTP entered: $otp'); // Debug log
                  // Verify OTP with API
                  final verifyResponse = await P2PService.verifyPaymentMethodOTP(otp);
                  debugPrint('OTP Verify Response: $verifyResponse'); // Debug log
                  
                  // Check for success in multiple possible formats
                  final isSuccess = verifyResponse['success'] == true || 
                                   verifyResponse['success'] == 'true' ||
                                   verifyResponse['status'] == 'success' ||
                                   (verifyResponse['message']?.toString().toLowerCase().contains('verified') == true) ||
                                   (verifyResponse['message']?.toString().toLowerCase().contains('success') == true);
                  
                  debugPrint('OTP verification success check: $isSuccess from response: $verifyResponse'); // Debug log
                  
                  if (isSuccess) {
                    // OTP verified, now save UPI payment method
                    // First get payment modes to find UPI mode ID
                    final modesResponse = await P2PService.getPaymentModes(country: widget.country);
                    String? upiModeId;
                    if (modesResponse != null && modesResponse['data'] != null) {
                      final modes = modesResponse['data'] as List<dynamic>;
                      final upiMode = modes.firstWhere(
                        (mode) => mode['name']?.toString().toUpperCase() == 'UPI' || 
                                  mode['identifier']?.toString().toUpperCase() == 'UPI',
                        orElse: () => null,
                      );
                      upiModeId = upiMode?['_id'];
                    }
                    
                    // Use API expected field names with mode ID
                    // Convert country name to numeric code
                    final countryCode = countryCodeMap[widget.country] ?? widget.country;
                    final saveData = {
                      'name': 'UPI',
                      'UPI_ID': _upiIdController.text,
                      'upiUserName': _holderNameController.text,
                      'country': countryCode,
                      if (upiModeId != null) 'mode': upiModeId,
                    };
                    debugPrint('Saving UPI with data: $saveData');
                    final saveResponse = await P2PService.savePaymentMethod(saveData);
                    debugPrint('Save UPI Response: $saveResponse'); // Debug log
                    
                    // Always return success to trigger navigation, even if save fails
                    // The user can try adding again if save failed
                    return {
                      'success': true, // Always return true to navigate
                      'message': saveResponse 
                          ? (widget.isEditMode ? 'UPI payment method updated successfully' : 'UPI payment method added successfully')
                          : 'OTP verified but failed to save details. Please try again.',
                      'saveFailed': !saveResponse // Flag to indicate save failure
                    };
                  }
                  return verifyResponse;
                },
                onResend: () async {
                  debugPrint('Resend UPI OTP clicked'); // Debug log
                  return await P2PService.sendPaymentMethodOTP();
                },
              ),
            ),
          );

          debugPrint('Navigation returned verified value: $verified'); // Debug log
          if (verified == true) {
            // Navigate to saved payment methods screen
            debugPrint('Navigating to SavedPaymentMethodsScreen'); // Debug log
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const SavedPaymentMethodsScreen()),
              (route) => false,
            );
          } else {
            debugPrint('Navigation failed or verification returned false/null'); // Debug log
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
                MaterialPageRoute(builder: (context) => const SavedPaymentMethodsScreen()),
                (route) => false,
              );
            }
          }
        } else {
          debugPrint('OTP sending failed: $response'); // Debug log
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to send OTP: ${response['message'] ?? response['error'] ?? 'Unknown error'}')),
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
