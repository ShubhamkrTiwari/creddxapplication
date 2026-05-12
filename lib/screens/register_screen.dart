import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../main_navigation.dart';
import '../widgets/bitcoin_loading_indicator.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _referralController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  bool _isLoading = false;
  bool _otpSent = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _referralController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (_emailController.text.isEmpty) {
      _showError('Please enter your email');
      return;
    }

    if (!_otpSent) {
      // Step 1: Send OTP
      setState(() {
        _isLoading = true;
      });

      try {
        final referralCode = _referralController.text.trim().isNotEmpty ? _referralController.text.trim() : null;
        final result = await AuthService.signupSendOtp(
          _emailController.text.trim(),
          referralCode: referralCode,
        );

        if (result['success']) {
          _showSuccess('OTP sent to your email!');
          setState(() {
            _otpSent = true;
          });
        } else {
          _showError(result['message']);
        }
      } catch (e) {
        _showError('Failed to send OTP');
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } else {
      // Step 2: Complete signup with OTP
      if (_otpController.text.isEmpty) {
        _showError('Please enter the OTP');
        return;
      }

      setState(() {
        _isLoading = true;
      });

      try {
        final referralCode = _referralController.text.trim().isNotEmpty ? _referralController.text.trim() : null;
        debugPrint('=== REGISTER SCREEN DEBUG ===');
        debugPrint('Email: ${_emailController.text.trim()}');
        debugPrint('OTP: ${_otpController.text.trim()}');
        debugPrint('Referral Code Raw: "${_referralController.text.trim()}"');
        debugPrint('Referral Code Is Empty: ${_referralController.text.trim().isEmpty}');
        debugPrint('Referral Code To Send: $referralCode');
        
        final result = await AuthService.completeSignupWithOtp(
          _emailController.text.trim(),
          _otpController.text.trim(),
          referralCode: referralCode,
        );

        if (result['success']) {
          _showSuccess('Registration successful!');
          // Navigate to main navigation with bottom nav bar and clear all previous screens
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const MainNavigation()),
            (Route<dynamic> route) => false,
          );
        } else {
          _showError(result['message']);
        }
      } catch (e) {
        _showError('Registration failed');
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFE74C3C),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF84BD00),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        backgroundColor: const Color(0xFF000000),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Image.asset(
              'assets/images/Creddxlogo.png',
              width: 80,
              height: 80,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const SizedBox(),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 30),
                const Text(
                  'Register',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Let's create new account",
                  style: TextStyle(fontSize: 16, color: Color(0xFF6C7278)),
                ),
                const SizedBox(height: 32),
                const Text('Email', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white)),
                const SizedBox(height: 8),
                _buildTextField(controller: _emailController, icon: Icons.email_outlined),
                const SizedBox(height: 24),
                const Text('Referral Code (Optional)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white)),
                const SizedBox(height: 8),
                _buildTextField(controller: _referralController, icon: Icons.card_giftcard_outlined),
                if (_otpSent) ...[
                  const SizedBox(height: 24),
                  const Text('OTP', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white)),
                  const SizedBox(height: 8),
                  _buildTextField(controller: _otpController, icon: Icons.lock_outline),
                ],
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleRegister,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isLoading ? Colors.grey : const Color(0xFF84BD00),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: OtpLoadingIndicator(size: 24, color: Colors.white),
                          )
                        : Text(_otpSent ? 'Complete Signup' : 'Send OTP', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 40),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Already have an account? ', style: TextStyle(fontSize: 14, color: Color(0xFF6C7278))),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Text('Login Here', style: TextStyle(fontSize: 14, color: Color(0xFF84BD00), fontWeight: FontWeight.w500)),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({required TextEditingController controller, required IconData icon, bool obscure = false, Widget? suffix, TextInputType? keyboardType}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white, fontSize: 16),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: const Color(0xFF6C7278)),
          suffixIcon: suffix,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }
}
