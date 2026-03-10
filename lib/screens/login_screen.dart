import 'package:flutter/material.dart';
import 'dart:async';
import 'register_screen.dart';
import '../main_navigation.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  bool _isLoading = false;
  bool _otpSent = false;
  int _resendTimer = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _emailController.text = 'yourname@gmail.com';
  }

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  // Start resend timer
  void _startResendTimer() {
    setState(() {
      _resendTimer = 30; // 30 seconds countdown
    });
    
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _resendTimer--;
        if (_resendTimer <= 0) {
          timer.cancel();
        }
      });
    });
  }

  Future<void> _handleLogin() async {
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
        final result = await AuthService.loginSendOtp(_emailController.text.trim());

        if (result['success']) {
          _showSuccess('OTP sent to your email!');
          setState(() {
            _otpSent = true;
            _isLoading = false;
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
      // Step 2: Verify OTP and login
      if (_otpController.text.isEmpty) {
        _showError('Please enter the OTP');
        return;
      }

      setState(() {
        _isLoading = true;
      });

      try {
        final result = await AuthService.loginWithOtp(
          _emailController.text.trim(),
          _otpController.text.trim(),
        );

        if (result['success']) {
          _showSuccess('Login successful!');
          // Navigate back to previous screen (P2P Trading) or to MainNavigation
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const MainNavigation()),
            );
          }
        } else {
          _showError(result['message']);
        }
      } catch (e) {
        _showError('Login failed');
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
                  'Sign in to your\naccount',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white, height: 1.2),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Let's login into your account first",
                  style: TextStyle(fontSize: 16, color: Color(0xFF6C7278)),
                ),
                const SizedBox(height: 40),
                const Text('Email', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white)),
                const SizedBox(height: 8),
                _buildTextField(
                  controller: _emailController,
                  prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF6C7278)),
                  enabled: !_otpSent, // Disable email field after OTP is sent
                ),
                if (_otpSent) ...[
                  const SizedBox(height: 24),
                  const Text('OTP', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white)),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _otpController,
                    prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF6C7278)),
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: _isLoading ? null : () async {
                        setState(() {
                          _isLoading = true;
                        });
                        
                        try {
                          final result = await AuthService.resendOtp(_emailController.text.trim());
                          if (result['success']) {
                            _showSuccess(result['message'] ?? 'OTP resent successfully!');
                            _startResendTimer();
                          } else {
                            _showError(result['error'] ?? 'Failed to resend OTP');
                          }
                        } catch (e) {
                          _showError('Failed to resend OTP');
                        } finally {
                          if (mounted) {
                            setState(() {
                              _isLoading = false;
                            });
                          }
                        }
                      },
                      child: Text(
                        _resendTimer > 0 
                            ? 'Resend OTP (${_resendTimer}s)'
                            : 'Resend OTP', 
                        style: TextStyle(
                          color: _isLoading || _resendTimer > 0 
                              ? Colors.grey 
                              : const Color(0xFF84BD00), 
                          fontWeight: FontWeight.w500
                        )
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isLoading ? Colors.grey : const Color(0xFF84BD00),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(_otpSent ? 'Verify OTP' : 'Send OTP', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 40),
                Center(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text("Don't have an account? ", style: TextStyle(fontSize: 14, color: Color(0xFF6C7278))),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const RegisterScreen()));
                        },
                        child: const Text('Register Here', style: TextStyle(fontSize: 14, color: Color(0xFF84BD00), fontWeight: FontWeight.w500)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({required TextEditingController controller, Widget? prefixIcon, bool obscure = false, Widget? suffix, bool enabled = true, TextInputType? keyboardType, int? maxLength}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        enabled: enabled,
        keyboardType: keyboardType,
        maxLength: maxLength,
        style: const TextStyle(color: Colors.white, fontSize: 16),
        decoration: InputDecoration(
          prefixIcon: prefixIcon,
          suffixIcon: suffix,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
          counterText: '',
        ),
      ),
    );
  }
}
