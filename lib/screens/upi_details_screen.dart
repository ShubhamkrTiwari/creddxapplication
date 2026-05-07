import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import '../services/wallet_service.dart';
import '../services/auth_service.dart';
import 'payment_proof_screen.dart';

class UpiDetailsScreen extends StatefulWidget {
  final String amount;
  
  const UpiDetailsScreen({super.key, required this.amount});

  @override
  State<UpiDetailsScreen> createState() => _UpiDetailsScreenState();
}

class _UpiDetailsScreenState extends State<UpiDetailsScreen> {
  bool _isLoading = true;
  List<dynamic> _upiList = [];
  Map<String, dynamic>? _selectedUpi;
  String? _selectedUpiApp;
  bool _paymentInitiated = false;
  bool _showUpiApps = false;

  // Map app names to their Android package names
  final Map<String, String> _upiPackageNames = {
    'gpay': 'com.google.android.apps.nbu.paisa.user',
    'paytm': 'net.one97.paytm',
    'phonepe': 'com.phonepe.app',
    'credd': 'com.dreamplug.androidapp',
  };

  @override
  void initState() {
    super.initState();
    _fetchUpiDetails();
  }

  Future<void> _openUpiApp(String appName, String upiString) async {
    final packageName = _upiPackageNames[appName];
    
    debugPrint('Opening UPI app: $appName with package: $packageName');
    debugPrint('UPI String: $upiString');
    
    try {
      final intent = AndroidIntent(
        action: 'android.intent.action.VIEW',
        data: upiString,
        package: packageName,
        flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
      );
      
      await intent.launch();
      debugPrint('Intent launched successfully');
      
      // Mark payment as initiated
      if (mounted) {
        setState(() {
          _paymentInitiated = true;
        });
      }
    } catch (e) {
      debugPrint('Error launching specific app: $e');
      final uri = Uri.parse(upiString);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        // Mark payment as initiated
        if (mounted) {
          setState(() {
            _paymentInitiated = true;
          });
        }
      } else {
        throw Exception('No UPI app found to handle payment');
      }
    }
  }

  Future<void> _fetchUpiDetails() async {
    try {
      final token = await AuthService.getToken();
      final response = await http.get(
        Uri.parse('${WalletService.baseUrl}/wallet/v1/wallet/deposit/upi-details'),
        headers: {
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        setState(() {
          final data = responseData is Map ? (responseData['data'] ?? responseData) : responseData;
          if (data is List) {
            _upiList = data;
            _selectedUpi = _upiList.isNotEmpty ? _upiList.first : null;
          }
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
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
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'UPI Details',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF84BD00)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_upiList.isNotEmpty) ...[
                    _buildUpiDropdown(),
                    const SizedBox(height: 20),
                  ],
                  // QR Code Section - Generated for selected UPI
                  if (_selectedUpi != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1C1E),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF2C2C2E)),
                      ),
                      child: Column(
                        children: [
                          // QR Code
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 200,
                                height: 200,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: QrImageView(
                                  data: 'upi://pay?pa=${_selectedUpi!['upiId']}&pn=${_selectedUpi!['accountHolderName'] ?? 'CreddX'}&mc=0000&tid=123456&tr=ORDER${DateTime.now().millisecondsSinceEpoch}&tn=Deposit&am=${widget.amount}&cu=INR',
                                  version: QrVersions.auto,
                                  size: 180,
                                  padding: const EdgeInsets.all(10),
                                ),
                              ),
                              // Logo in center
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(6),
                                  child: Image.asset(
                                    'assets/images/logogoogle.png',
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // UPI ID and Amount with copy buttons
                          Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    'UPI ID: ',
                                    style: TextStyle(color: Color(0xFF8E8E93), fontSize: 14),
                                  ),
                                  Text(
                                    _selectedUpi!['upiId'] ?? 'N/A',
                                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () async {
                                      await Clipboard.setData(ClipboardData(text: _selectedUpi!['upiId'] ?? ''));
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('UPI ID copied!'),
                                            backgroundColor: Color(0xFF84BD00),
                                            duration: Duration(seconds: 2),
                                          ),
                                        );
                                      }
                                    },
                                    child: const Icon(
                                      Icons.copy,
                                      color: Color(0xFF84BD00),
                                      size: 18,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    'Amount: ',
                                    style: TextStyle(color: Color(0xFF8E8E93), fontSize: 14),
                                  ),
                                  Text(
                                    '₹${widget.amount}',
                                    style: const TextStyle(color: Color(0xFF84BD00), fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () async {
                                      await Clipboard.setData(ClipboardData(text: widget.amount));
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Amount copied!'),
                                            backgroundColor: Color(0xFF84BD00),
                                            duration: Duration(seconds: 2),
                                          ),
                                        );
                                      }
                                    },
                                    child: const Icon(
                                      Icons.copy,
                                      color: Color(0xFF84BD00),
                                      size: 18,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Scan to pay',
                            style: TextStyle(color: Color(0xFF8E8E93), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  // UPI App Selection
                  if (_selectedUpi != null) ...[
                    const SizedBox(height: 24),
                    const Text(
                      'Select UPI App to Pay',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Or skip to directly submit payment proof',
                      style: TextStyle(color: Color(0xFF8E8E93), fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    
                    // UPI App Selector (Expandable)
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _showUpiApps = !_showUpiApps;
                        });
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1C1C1E),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF2C2C2E)),
                        ),
                        child: Row(
                          children: [
                            // Show selected app icon or default icon
                            if (_selectedUpiApp != null) ...[
                              _getAppIcon(_selectedUpiApp!),
                            ] else ...[
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF84BD00).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(
                                  Icons.account_balance_wallet,
                                  color: Color(0xFF84BD00),
                                  size: 16,
                                ),
                              ),
                            ],
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _selectedUpiApp != null 
                                    ? _getAppName(_selectedUpiApp!)
                                    : 'Choose UPI App',
                                style: const TextStyle(color: Colors.white, fontSize: 16),
                              ),
                            ),
                            Icon(
                              _showUpiApps ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                              color: const Color(0xFF8E8E93),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // Show UPI app options when expanded
                    if (_showUpiApps) ...[
                      const SizedBox(height: 12),
                      _buildUpiAppOption(
                        appName: 'gpay',
                        logo: Image.asset(
                          'assets/images/logogoogle.png',
                          width: 24,
                          height: 24,
                        ),
                        label: 'GPay',
                      ),
                      const SizedBox(height: 10),
                      _buildUpiAppOption(
                        appName: 'paytm',
                        logo: RichText(
                          text: const TextSpan(
                            children: [
                              TextSpan(
                                text: 'Pay',
                                style: TextStyle(
                                  color: Color(0xFF20336B),
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              TextSpan(
                                text: 'tm',
                                style: TextStyle(
                                  color: Color(0xFF00BAF2),
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        label: 'Paytm',
                      ),
                      const SizedBox(height: 10),
                      _buildUpiAppOption(
                        appName: 'phonepe',
                        logo: Container(
                          width: 24,
                          height: 24,
                          decoration: const BoxDecoration(
                            color: Color(0xFF6739B7),
                            borderRadius: BorderRadius.all(Radius.circular(4)),
                          ),
                          child: const Center(
                            child: Text(
                              'P',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        label: 'PhonePe',
                      ),
                      const SizedBox(height: 10),
                      _buildUpiAppOption(
                        appName: 'credd',
                        logo: Image.asset(
                          'assets/images/cred.png',
                          width: 28,
                          height: 28,
                        ),
                        label: 'CREDD UPI',
                      ),
                    ],
                    const SizedBox(height: 20),
                    // Payment Proof Section - Show after payment is initiated
                    if (_paymentInitiated) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF84BD00).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF84BD00).withOpacity(0.3)),
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.check_circle_outline,
                              color: Color(0xFF84BD00),
                              size: 32,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Payment Initiated',
                              style: TextStyle(
                                color: Color(0xFF84BD00),
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Complete your payment in the UPI app and submit proof below',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              height: 45,
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => PaymentProofScreen(
                                        amount: widget.amount,
                                        paymentMethod: 'UPI Payment',
                                        account: _selectedUpi?['_id']?.toString(),
                                        senderAccountName: _selectedUpi?['accountHolderName'],
                                      ),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF84BD00),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  elevation: 0,
                                ),
                                child: const Text(
                                  'Submit Payment Proof',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () async {
                if (_selectedUpi == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('No UPI selected')),
                  );
                  return;
                }
                
                // If no UPI app selected, go directly to payment proof screen
                if (_selectedUpiApp == null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PaymentProofScreen(
                        amount: widget.amount,
                        paymentMethod: 'UPI Payment',
                        account: _selectedUpi?['_id']?.toString(),
                        senderAccountName: _selectedUpi?['accountHolderName'],
                      ),
                    ),
                  );
                  return;
                }
                
                // Build UPI payment URI string with selected UPI details
                final upiId = _selectedUpi!['upiId']?.toString() ?? 'creddx1234@oksbi';
                final merchantName = _selectedUpi!['accountHolderName']?.toString() ?? 'CreddX';
                final upiString = 'upi://pay?pa=$upiId&pn=$merchantName&mc=0000&tr=ORDER${DateTime.now().millisecondsSinceEpoch}&tn=CreddX%20Deposit&am=${widget.amount}&cu=INR';
                
                // Launch UPI app
                try {
                  await _openUpiApp(_selectedUpiApp!, upiString);
                } catch (e) {
                  if (context.mounted) {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: const Color(0xFF1C1C1E),
                        title: const Text(
                          'UPI App Not Found',
                          style: TextStyle(color: Colors.white),
                        ),
                        content: Text(
                          '${_selectedUpiApp?.toUpperCase()} is not installed. Please install it or select another UPI app.',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text(
                              'OK',
                              style: TextStyle(color: Color(0xFF84BD00)),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF84BD00),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: Text(
                _paymentInitiated 
                    ? 'Payment Initiated' 
                    : _selectedUpiApp == null 
                        ? 'Submit Payment Proof' 
                        : 'Pay Now',
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUpiAppOption({
    required String appName,
    required Widget logo,
    required String label,
  }) {
    final isSelected = _selectedUpiApp == appName;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedUpiApp = appName;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(8),
          border: isSelected 
              ? Border.all(color: const Color(0xFF84BD00), width: 2)
              : null,
        ),
        child: Row(
          children: [
            logo,
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: Color(0xFF84BD00),
                size: 22,
              )
            else
              const Icon(Icons.chevron_right, color: Color(0xFF8E8E93)),
          ],
        ),
      ),
    );
  }

  Widget _buildUpiDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Map<String, dynamic>>(
          value: _selectedUpi,
          isExpanded: true,
          dropdownColor: const Color(0xFF1C1C1E),
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
          style: const TextStyle(color: Colors.white, fontSize: 16),
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _selectedUpi = value;
              });
            }
          },
          items: _upiList.map<DropdownMenuItem<Map<String, dynamic>>>((upi) {
            return DropdownMenuItem<Map<String, dynamic>>(
              value: upi,
              child: Text(upi['Name'] ?? 'Unknown UPI'),
            );
          }).toList(),
        ),
      ),
    );
  }

  // Helper functions for app icon and name
  Widget _getAppIcon(String appName) {
    switch (appName) {
      case 'gpay':
        return Image.asset('assets/images/logogoogle.png', width: 24, height: 24);
      case 'paytm':
        return RichText(
          text: const TextSpan(
            children: [
              TextSpan(
                text: 'Pay',
                style: TextStyle(
                  color: Color(0xFF20336B),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextSpan(
                text: 'tm',
                style: TextStyle(
                  color: Color(0xFF00BAF2),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      case 'phonepe':
        return Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            color: Color(0xFF6739B7),
            borderRadius: BorderRadius.all(Radius.circular(4)),
          ),
          child: const Center(
            child: Text(
              'P',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      case 'credd':
        return Image.asset('assets/images/cred.png', width: 28, height: 28);
      default:
        return Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: const Color(0xFF84BD00).withOpacity(0.2),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Icon(
            Icons.account_balance_wallet,
            color: Color(0xFF84BD00),
            size: 16,
          ),
        );
    }
  }

  String _getAppName(String appName) {
    switch (appName) {
      case 'gpay':
        return 'GPay';
      case 'paytm':
        return 'Paytm';
      case 'phonepe':
        return 'PhonePe';
      case 'credd':
        return 'CREDD UPI';
      default:
        return 'Unknown App';
    }
  }
}
