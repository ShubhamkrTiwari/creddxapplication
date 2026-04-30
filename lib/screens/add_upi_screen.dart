import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/p2p_service.dart';
import 'otp_verification_screen.dart';
import 'saved_payment_methods_screen.dart';

// Country name to numeric code mapping for API
const Map<String, String> countryCodeMap = {
  'Afghanistan': '93',
  'Albania': '355',
  'Algeria': '213',
  'Andorra': '376',
  'Angola': '244',
  'Argentina': '54',
  'Armenia': '374',
  'Australia': '61',
  'Austria': '43',
  'Azerbaijan': '994',
  'Bahrain': '973',
  'Bangladesh': '880',
  'Belarus': '375',
  'Belgium': '32',
  'Belize': '501',
  'Benin': '229',
  'Bhutan': '975',
  'Bolivia': '591',
  'Bosnia and Herzegovina': '387',
  'Botswana': '267',
  'Brazil': '55',
  'Brunei': '673',
  'Bulgaria': '359',
  'Burkina Faso': '226',
  'Burundi': '257',
  'Cambodia': '855',
  'Cameroon': '237',
  'Canada': '1',
  'Cape Verde': '238',
  'Central African Republic': '236',
  'Chad': '235',
  'Chile': '56',
  'China': '86',
  'Colombia': '57',
  'Comoros': '269',
  'Congo': '243',
  'Congo (Republic)': '242',
  'Costa Rica': '506',
  'Croatia': '385',
  'Cuba': '53',
  'Cyprus': '357',
  'Czech Republic': '420',
  'Denmark': '45',
  'Djibouti': '253',
  'Ecuador': '593',
  'Egypt': '20',
  'El Salvador': '503',
  'Equatorial Guinea': '240',
  'Eritrea': '291',
  'Estonia': '372',
  'Ethiopia': '251',
  'Fiji': '679',
  'Finland': '358',
  'France': '33',
  'Gabon': '241',
  'Gambia': '220',
  'Georgia': '995',
  'Germany': '49',
  'Ghana': '233',
  'Greece': '30',
  'Guatemala': '502',
  'Guinea': '224',
  'Guinea-Bissau': '245',
  'Guyana': '592',
  'Haiti': '509',
  'Honduras': '504',
  'Hong Kong': '852',
  'Hungary': '36',
  'Iceland': '354',
  'India': '91',
  'Indonesia': '62',
  'Iran': '98',
  'Iraq': '964',
  'Ireland': '353',
  'Israel': '972',
  'Italy': '39',
  'Ivory Coast': '225',
  'Japan': '81',
  'Jordan': '962',
  'Kazakhstan': '7',
  'Kenya': '254',
  'Kiribati': '686',
  'Kuwait': '965',
  'Kyrgyzstan': '996',
  'Laos': '856',
  'Latvia': '371',
  'Lebanon': '961',
  'Lesotho': '266',
  'Liberia': '231',
  'Libya': '218',
  'Liechtenstein': '423',
  'Lithuania': '370',
  'Luxembourg': '352',
  'Macau': '853',
  'Macedonia': '389',
  'Madagascar': '261',
  'Malawi': '265',
  'Malaysia': '60',
  'Maldives': '960',
  'Mali': '223',
  'Malta': '356',
  'Marshall Islands': '692',
  'Mauritania': '222',
  'Mauritius': '230',
  'Mexico': '52',
  'Micronesia': '691',
  'Moldova': '373',
  'Monaco': '377',
  'Mongolia': '976',
  'Montenegro': '382',
  'Morocco': '212',
  'Mozambique': '258',
  'Myanmar': '95',
  'Namibia': '264',
  'Nauru': '674',
  'Nepal': '977',
  'Netherlands': '31',
  'New Zealand': '64',
  'Nicaragua': '505',
  'Niger': '227',
  'Nigeria': '234',
  'North Korea': '850',
  'Norway': '47',
  'Oman': '968',
  'Pakistan': '92',
  'Palau': '680',
  'Panama': '507',
  'Papua New Guinea': '675',
  'Paraguay': '595',
  'Peru': '51',
  'Philippines': '63',
  'Poland': '48',
  'Portugal': '351',
  'Qatar': '974',
  'Romania': '40',
  'Russia': '7',
  'Rwanda': '250',
  'San Marino': '378',
  'Sao Tome and Principe': '239',
  'Saudi Arabia': '966',
  'Senegal': '221',
  'Serbia': '381',
  'Seychelles': '248',
  'Sierra Leone': '232',
  'Singapore': '65',
  'Slovakia': '421',
  'Slovenia': '386',
  'Solomon Islands': '677',
  'Somalia': '252',
  'South Africa': '27',
  'South Korea': '82',
  'South Sudan': '211',
  'Spain': '34',
  'Sri Lanka': '94',
  'Sudan': '249',
  'Suriname': '597',
  'Swaziland': '268',
  'Sweden': '46',
  'Switzerland': '41',
  'Syria': '963',
  'Taiwan': '886',
  'Tajikistan': '992',
  'Tanzania': '255',
  'Thailand': '66',
  'Togo': '228',
  'Tonga': '676',
  'Tunisia': '216',
  'Turkey': '90',
  'Turkmenistan': '993',
  'Uganda': '256',
  'Ukraine': '380',
  'UAE': '971',
  'United Arab Emirates': '971',
  'UK': '44',
  'United Kingdom': '44',
  'Uruguay': '598',
  'USA': '1',
  'United States': '1',
  'United States of America': '1',
  'Uzbekistan': '998',
  'Venezuela': '58',
  'Vietnam': '84',
  'Yemen': '967',
  'Zambia': '260',
  'Zimbabwe': '263',
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
