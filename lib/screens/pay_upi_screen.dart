import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'payment_proof_screen.dart';

class PayUpiScreen extends StatefulWidget {
  final String amount;
  final Map<String, dynamic>? upiDetails;
  
  const PayUpiScreen({super.key, required this.amount, this.upiDetails});

  @override
  State<PayUpiScreen> createState() => _PayUpiScreenState();
}

class _PayUpiScreenState extends State<PayUpiScreen> {
  String? _selectedUpiApp;

  // Map app names to their Android package names
  final Map<String, String> _upiPackageNames = {
    'gpay': 'com.google.android.apps.nbu.paisa.user',
    'paytm': 'net.one97.paytm',
    'phonepe': 'com.phonepe.app',
    'credd': 'com.dreamplug.androidapp',
  };

  Future<void> _openUpiApp(String appName, String upiString) async {
    final packageName = _upiPackageNames[appName];
    
    debugPrint('Opening UPI app: $appName with package: $packageName');
    debugPrint('UPI String: $upiString');
    
    try {
      // For Android, use explicit intent with component
      final intent = AndroidIntent(
        action: 'android.intent.action.VIEW',
        data: upiString,
        package: packageName,
        flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
      );
      
      await intent.launch();
      debugPrint('Intent launched successfully');
    } catch (e) {
      debugPrint('Error launching specific app: $e');
      // Fallback to generic UPI intent
      final uri = Uri.parse(upiString);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw Exception('No UPI app found to handle payment');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get UPI details from selected or use defaults
    final upiId = widget.upiDetails?['upiId']?.toString() ?? 'creddx1234@oksbi';
    final merchantName = widget.upiDetails?['accountHolderName']?.toString() ?? 'CreddX';
    final qrData = 'upi://pay?pa=$upiId&pn=$merchantName&mc=0000&tid=123456&tr=ORDER123&tn=Deposit&am=${widget.amount}&cu=INR';
    
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
          'Pay Using UPI',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // QR Code Container
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
                  // QR Code with GPay Logo
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
                          data: qrData,
                          version: QrVersions.auto,
                          size: 180,
                          padding: const EdgeInsets.all(10),
                        ),
                      ),
                      // GPay Logo in center
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
                  // UPI ID with copy button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        upiId,
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          // Copy to clipboard
                        },
                        child: const Icon(
                          Icons.copy,
                          color: Color(0xFF8E8E93),
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Pay by any UPI App
            const Text(
              'Pay by any UPI App',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
            ),
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
                if (_selectedUpiApp == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please select a UPI app')),
                  );
                  return;
                }
                
                // Build UPI payment URI
                final upiId = widget.upiDetails?['upiId']?.toString() ?? 'creddx1234@oksbi';
                final merchantName = widget.upiDetails?['accountHolderName']?.toString() ?? 'CreddX';
                final upiUri = Uri.parse(
                  'upi://pay?pa=$upiId&pn=$merchantName&tr=ORDER${DateTime.now().millisecondsSinceEpoch}&tn=CreddX%20Deposit&am=${widget.amount}&cu=INR',
                );
                
                debugPrint('UPI URI: $upiUri');
                
                // Launch UPI app
                try {
                  final canLaunch = await canLaunchUrl(upiUri);
                  debugPrint('Can launch: $canLaunch');
                  
                  if (canLaunch) {
                    final result = await launchUrl(
                      upiUri, 
                      mode: LaunchMode.externalNonBrowserApplication,
                    );
                    debugPrint('Launch result: $result');
                  } else {
                    throw Exception('Cannot launch UPI URL - no UPI app installed');
                  }
                } catch (e) {
                  debugPrint('Launch error: $e');
                  if (context.mounted) {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: const Color(0xFF1C1C1E),
                        title: const Text(
                          'UPI App Error',
                          style: TextStyle(color: Colors.white),
                        ),
                        content: Text(
                          'Error: ${e.toString()}\n\nPlease ensure you have a UPI app (GPay, PhonePe, Paytm) installed.',
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
              child: const Text(
                'Proceed',
                style: TextStyle(
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
}
