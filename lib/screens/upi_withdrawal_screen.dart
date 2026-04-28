import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';
import '../services/wallet_service.dart';
import '../services/notification_service.dart';
import 'otp_verification_screen.dart';

class UpWithdrawalScreen extends StatefulWidget {
  final Map<String, dynamic>? upiDetails;
  
  const UpWithdrawalScreen({super.key, this.upiDetails});

  @override
  State<UpWithdrawalScreen> createState() => _UpWithdrawalScreenState();
}

class _UpWithdrawalScreenState extends State<UpWithdrawalScreen> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _upiController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.upiDetails != null) {
      _upiController.text = widget.upiDetails!['upiId'] ?? '';
      _nameController.text = widget.upiDetails!['accountHolderName'] ?? '';
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _upiController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submitWithdrawal() async {
    if (_amountController.text.isEmpty || _upiController.text.isEmpty || _nameController.text.isEmpty) {
      _showError('Please fill all fields');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final token = await AuthService.getToken();
      
      // Step 1: Send OTP first
      final otpResult = await WalletService.sendOtp(purpose: 'inr_withdraw');
      
      if (otpResult['success'] == true) {
        if (!mounted) return;
        
        // Step 2: Navigate to OTP Verification Screen
        final bool? verified = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (context) => OtpVerificationScreen(
              onVerify: (otp) async {
                final result = await WalletService.submitInrWithdrawal(
                  amount: double.tryParse(_amountController.text) ?? 0.0,
                  paymentMode: 'upi', 
                  accountHolderName: _nameController.text,
                  upiId: _upiController.text,
                  token: token,
                  otp: otp,
                );
                return result ?? {'success': false, 'message': 'Unknown error occurred'};
              },
              onResend: () => WalletService.sendOtp(purpose: 'inr_withdraw'),
            ),
          ),
        );

        if (verified == true) {
          if (mounted) {
            await NotificationService.addNotification(
              title: 'UPI Withdrawal Submitted',
              message: 'Your UPI withdrawal of ₹${_amountController.text} to ${_upiController.text} was submitted successfully.',
              type: NotificationType.transaction,
            );
            // Navigate to success screen instead of popping
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => _buildSuccessScreen(),
              ),
            );
          }
        }
      } else {
        _showError(otpResult['error'] ?? 'Failed to send OTP');
      }
    } catch (e) {
      if (mounted) {
        _showError('Error: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: const Color(0xFF84BD00)),
    );
  }

  Widget _buildSuccessScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF84BD00).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF84BD00),
                  size: 100,
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Withdrawal Initiated',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Your UPI withdrawal request of ₹${_amountController.text} has been submitted successfully.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _buildSuccessDetailRow('UPI ID', _upiController.text),
                    const SizedBox(height: 8),
                    _buildSuccessDetailRow('Account Holder', _nameController.text),
                    const SizedBox(height: 8),
                    _buildSuccessDetailRow('Amount', '₹${_amountController.text}'),
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF84BD00),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    'Done',
                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 14)),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
      ],
    );
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
        title: const Text('UPI Withdrawal', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLabel('Withdrawal Amount'),
            const SizedBox(height: 8),
            _buildTextField(controller: _amountController, hintText: '0.00', keyboardType: TextInputType.number),
            const SizedBox(height: 24),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('UPI ID'),
                    const SizedBox(height: 8),
                    _buildTextField(controller: _upiController, hintText: 'Enter UPI ID', keyboardType: TextInputType.emailAddress),
                    const SizedBox(height: 16),
                    _buildLabel('Account Holder Name'),
                    const SizedBox(height: 8),
                    _buildTextField(controller: _nameController, hintText: 'Enter account holder name'),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitWithdrawal,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF84BD00),
                  disabledBackgroundColor: Colors.white10,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                    : const Text('Confirm & Send OTP', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(text, style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 14));
  }

  Widget _buildTextField({required TextEditingController controller, required String hintText, TextInputType keyboardType = TextInputType.text}) {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(8)),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white, fontSize: 16),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(color: Color(0xFF8E8E93)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}
