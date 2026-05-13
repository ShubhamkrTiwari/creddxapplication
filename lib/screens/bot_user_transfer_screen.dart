import 'dart:async';

import 'package:flutter/material.dart';

import '../services/bot_service.dart';
import '../services/unified_wallet_service.dart';
import 'bot_transfer_otp_screen.dart';

class BotUserTransferScreen extends StatefulWidget {
  const BotUserTransferScreen({super.key});

  @override
  State<BotUserTransferScreen> createState() => _BotUserTransferScreenState();
}

class _BotUserTransferScreenState extends State<BotUserTransferScreen> {
  final TextEditingController _userIdController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  bool _isLoading = false;
  double _availableBalance = 0.0;
  StreamSubscription? _balanceSubscription;

  @override
  void initState() {
    super.initState();
    _fetchBalance();
    _subscribeToBalance();
  }

  @override
  void dispose() {
    _balanceSubscription?.cancel();
    _userIdController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _subscribeToBalance() {
    _balanceSubscription = UnifiedWalletService.walletBalanceStream.listen((balance) {
      if (mounted && balance != null) {
        setState(() {
          _availableBalance = balance.botBalance;
        });
      }
    });
  }

  Future<void> _fetchBalance() async {
    try {
      final response = await BotService.getBotBalance();
      if (mounted && response['success'] == true && response['data'] != null) {
        final data = response['data'];
        setState(() {
          _availableBalance = double.tryParse(data['availableBalance']?.toString() ?? '0') ?? 0.0;
        });
      }
    } catch (e) {
      debugPrint('Error fetching bot balance: $e');
    }
  }

  Future<void> _handleTransfer() async {
    final userId = _userIdController.text.trim();
    final amountText = _amountController.text.trim();

    if (userId.isEmpty) {
      _showError('Please enter Receiver User ID');
      return;
    }

    if (amountText.isEmpty) {
      _showError('Please enter amount');
      return;
    }

    final amount = double.tryParse(amountText) ?? 0;
    if (amount <= 0) {
      _showError('Enter a valid amount');
      return;
    }

    if (amount > _availableBalance) {
      _showError('Insufficient balance in Bot wallet');
      return;
    }

    // Send OTP and navigate to OTP verification screen
    setState(() => _isLoading = true);

    try {
      final result = await BotService.sendBotWalletOtp(purpose: 'internal-transfer');

      if (!mounted) return;

      if (result['success'] == true) {
        // Navigate to OTP verification screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BotTransferOtpScreen(
              receiverUid: userId,
              amount: amount,
            ),
          ),
        );
      } else {
        _showError(result['error'] ?? 'Failed to send OTP');
      }
    } catch (e) {
      if (mounted) _showError('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('User to User Transfer', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Transfer funds directly to another user using their User ID.',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
            const SizedBox(height: 32),
            
            const Text('Receiver User ID', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500)),
            const SizedBox(height: 12),
            TextField(
              controller: _userIdController,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF1C1C1E),
                hintText: 'Enter User ID',
                hintStyle: const TextStyle(color: Colors.white24),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF84BD00)),
              ),
            ),
            
            const SizedBox(height: 24),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Amount', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500)),
                Text('Available: ${_availableBalance.toStringAsFixed(2)} USDT', style: const TextStyle(color: Color(0xFF84BD00), fontSize: 12)),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF1C1C1E),
                hintText: '0.00',
                hintStyle: const TextStyle(color: Colors.white24),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                suffixText: 'USDT',
                suffixStyle: const TextStyle(color: Color(0xFF84BD00), fontWeight: FontWeight.bold),
                prefixIcon: const Icon(Icons.account_balance_wallet_outlined, color: Color(0xFF84BD00)),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: () => _amountController.text = _availableBalance.toString(),
                child: const Text('Use Max', style: TextStyle(color: Color(0xFF84BD00), fontSize: 13, fontWeight: FontWeight.bold)),
              ),
            ),
            
            const SizedBox(height: 48),
            
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleTransfer,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF84BD00),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                    : const Text('Transfer Now', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withOpacity(0.2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue, size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Internal transfers are instant and have zero fees when sending to other CreddX users.',
                      style: TextStyle(color: Colors.blue, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
