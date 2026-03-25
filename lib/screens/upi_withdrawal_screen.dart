import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';
import '../services/wallet_service.dart';

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
      
      // Fixed: Changed paymentMode to 'upi'
      final result = await WalletService.submitInrWithdrawal(
        amount: double.tryParse(_amountController.text) ?? 0.0,
        paymentMode: 'upi', 
        accountHolderName: _nameController.text,
        upiId: _upiController.text,
        token: token,
      );
      
      if (mounted) {
        if (result != null && result['success'] == true) {
          _showSuccess('UPI withdrawal request submitted successfully');
          Navigator.of(context).popUntil((route) => route.isFirst);
        } else {
          _showError(result?['error'] ?? 'Withdrawal failed');
        }
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
                    : const Text('Submit Withdrawal', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
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
