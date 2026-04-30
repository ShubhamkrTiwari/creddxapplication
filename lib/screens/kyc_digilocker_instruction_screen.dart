import 'package:flutter/material.dart';
import 'kyc_digilocker_screen.dart';
import 'kyc_selfie_screen.dart';
import 'user_profile_screen.dart';
import '../services/user_service.dart';

class KYCDigiLockerInstructionScreen extends StatefulWidget {
  const KYCDigiLockerInstructionScreen({super.key});

  @override
  State<KYCDigiLockerInstructionScreen> createState() =>
      _KYCDigiLockerInstructionScreenState();
}

class _KYCDigiLockerInstructionScreenState
    extends State<KYCDigiLockerInstructionScreen> {
  final UserService _userService = UserService();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkKYCStatusAndRedirect();
      _checkProfileAndShowDialog();
    });
  }

  Future<void> _checkKYCStatusAndRedirect() async {
    try {
      await _userService.fetchProfileDataFromAPI();
      if (!mounted) return;

      if (_userService.shouldResumeKYCAtSelfieStep) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const KYCSelfieScreen()),
        );
        return;
      }

      final status = _userService.kycStatus.toLowerCase();
      if (status == 'completed' ||
          status == 'verified' ||
          status == 'approved') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your KYC is already verified!'),
            backgroundColor: Color(0xFF84BD00),
          ),
        );
        Navigator.of(context).pop();
        return;
      }

      // If KYC is pending but document not verified (incomplete), allow restart
      if (_userService.canRestartKYC()) {
        // Don't block - let user proceed to restart KYC
        return;
      }

      if (status == 'pending' ||
          status == 'submitted' ||
          status == 'processing') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your KYC is already under review.'),
            backgroundColor: Colors.orange,
          ),
        );
        Navigator.of(context).pop();
        return;
      }
    } catch (e) {
      debugPrint('Error checking KYC status on instruction screen: $e');
    }
  }

  // Check if profile is complete
  bool _isProfileComplete() {
    return _userService.hasEmail() &&
        _userService.userPhone != null &&
        _userService.userPhone!.isNotEmpty;
  }

  // Check profile and show dialog if incomplete
  void _checkProfileAndShowDialog() {
    if (!_isProfileComplete()) {
      _showProfileRequiredDialog();
    }
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
            'Profile Incomplete',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'Please complete your profile (email and phone number) before starting KYC verification.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop(); // Go back to previous screen
              },
              child: const Text(
                'Go Back',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const UserProfileScreen(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF84BD00),
              ),
              child: const Text(
                'Complete Profile',
                style: TextStyle(color: Colors.black),
              ),
            ),
          ],
        );
      },
    );
  }

  void _proceedToKYC() {
    if (_isProfileComplete()) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const KYCDigiLockerScreen()),
      );
    } else {
      _showProfileRequiredDialog();
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
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          },
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Know Your Customers (KYC)',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Text(
              'DigiLocker Setup (1/2)',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            // Header Icon
            Center(
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: const Color(0xFF84BD00).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: const Icon(
                  Icons.account_balance_wallet,
                  color: Color(0xFF84BD00),
                  size: 50,
                ),
              ),
            ),
            const SizedBox(height: 30),
            // Title
            const Center(
              child: Text(
                'Verify with DigiLocker',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Description
            const Center(
              child: Text(
                'We use DigiLocker to securely verify your identity documents. This is a quick and paperless process.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 40),
            // Instructions
            const Text(
              'What you will need:',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            _buildInstructionItem(
              icon: Icons.smartphone,
              title: 'DigiLocker Account',
              description:
                  'You need an active DigiLocker account linked to your mobile number.',
            ),
            const SizedBox(height: 16),
            _buildInstructionItem(
              icon: Icons.description,
              title: 'Aadhaar Linked',
              description:
                  'Your DigiLocker should have your Aadhaar card linked for verification.',
            ),
            const SizedBox(height: 16),
            _buildInstructionItem(
              icon: Icons.security,
              title: 'Secure Process',
              description:
                  'Your data is securely fetched directly from DigiLocker. We do not store your documents.',
            ),
            const SizedBox(height: 40),
            // Steps
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'How it works:',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildStepItem('1', 'Tap Continue to connect DigiLocker'),
                  const SizedBox(height: 12),
                  _buildStepItem('2', 'Login with your DigiLocker credentials'),
                  const SizedBox(height: 12),
                  _buildStepItem('3', 'Grant permission to share documents'),
                  const SizedBox(height: 12),
                  _buildStepItem('4', 'We verify and fetch your details'),
                ],
              ),
            ),
            const SizedBox(height: 40),
            // Continue Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _proceedToKYC,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF84BD00),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Continue',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Back Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1C1C1E),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Back',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFF84BD00).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xFF84BD00), size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStepItem(String number, String text) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: const Color(0xFF84BD00),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ),
      ],
    );
  }
}
