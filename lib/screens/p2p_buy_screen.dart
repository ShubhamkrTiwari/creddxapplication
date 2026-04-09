import 'package:flutter/material.dart';
import 'dart:convert';
import '../services/p2p_service.dart';
import 'make_payment_screen.dart';

class P2PBuyScreen extends StatefulWidget {
  const P2PBuyScreen({super.key});

  @override
  State<P2PBuyScreen> createState() => _P2PBuyScreenState();
}

class _P2PBuyScreenState extends State<P2PBuyScreen> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _depositController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  
  String _selectedPaymentMethod = 'Bank';
  bool _isTermsAccepted = false;
  bool _isLoading = false;
  String _selectedCoin = 'USDT';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _amountController.addListener(_calculateDeposit);
    _priceController.addListener(_calculateDeposit);
  }

  void _calculateDeposit() {
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    final price = double.tryParse(_priceController.text) ?? 0.0;
    final deposit = amount * price;
    _depositController.text = deposit.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _depositController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _createBuyAd() async {
    if (_amountController.text.isEmpty || _priceController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final adData = {
        "coin": _selectedCoin,
        "coinSymbol": _selectedCoin,
        "price": double.tryParse(_priceController.text) ?? 0.0,
        "amount": double.tryParse(_amountController.text) ?? 0.0,
        "quantity": double.tryParse(_amountController.text) ?? 0.0,
        "payModes": [_selectedPaymentMethod],
        "type": "buy",
        "direction": 1,
        "currency": "INR",
        "payTime": 15,
        "status": "active", // Set advertisement as active
      };

      debugPrint('Creating buy advertisement with data: ${json.encode(adData)}');
      
      final success = await P2PService.createAdvertisement(adData);

      if (mounted) {
        setState(() => _isLoading = false);
        if (success['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Buy advertisement created successfully!'), backgroundColor: Color(0xFF84BD00)),
          );
          
          // Clear form after successful creation
          _amountController.clear();
          _priceController.clear();
          _depositController.clear();
          
          // Optionally navigate back or refresh advertisements list
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to create advertisement'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
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
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Buy USDT', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF84BD00)))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_errorMessage != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.red.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                    child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                  ),
                  const SizedBox(height: 16),
                ],
                _buildAmountInput(),
                const SizedBox(height: 16),
                _buildDepositInput(),
                const SizedBox(height: 24),
                _buildTradeInfo(),
                const SizedBox(height: 32),
                _buildPlaceOrderButton(),
              ],
            ),
          ),
    );
  }

  Widget _buildAmountInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Crypto Amount', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _amountController,
                  style: const TextStyle(color: Colors.white),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(hintText: 'Enter amount', hintStyle: TextStyle(color: Color(0xFF8E8E93)), border: InputBorder.none),
                ),
              ),
              const Text('USDT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            if (_priceController.text.isNotEmpty)
              Text('Price: ${_priceController.text} INR', style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 12))
            else
              const Text('Set price below', style: TextStyle(color: Color(0xFF8E8E93), fontSize: 12)),
          ],
        ),
      ],
    );
  }

  Widget _buildDepositInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Amount to Deposit', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _depositController,
                  style: const TextStyle(color: Colors.white),
                  keyboardType: TextInputType.number,
                  enabled: false,
                  decoration: const InputDecoration(hintText: '0.00', hintStyle: TextStyle(color: Color(0xFF8E8E93)), border: InputBorder.none),
                ),
              ),
              const Text('INR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTradeInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Trade Information', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(12)),
          child: Column(
            children: [
              // Price input row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Price per USDT', style: TextStyle(color: Color(0xFF8E8E93), fontSize: 14)),
                  SizedBox(
                    width: 100,
                    child: TextField(
                      controller: _priceController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.right,
                      decoration: const InputDecoration(
                        hintText: '0',
                        hintStyle: TextStyle(color: Color(0xFF8E8E93)),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: (_) => _calculateDeposit(),
                    ),
                  ),
                  const Text('INR', style: TextStyle(color: Colors.white, fontSize: 14)),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(color: Color(0xFF2C2C2E)),
              const SizedBox(height: 12),
              // EST Time row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('EST Time', style: TextStyle(color: Color(0xFF8E8E93), fontSize: 14)),
                  Row(
                    children: [
                      const Icon(Icons.access_time, color: Color(0xFF84BD00), size: 16),
                      const SizedBox(width: 4),
                      Text('15 min', style: const TextStyle(color: Colors.white, fontSize: 14)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(color: Color(0xFF2C2C2E)),
              const SizedBox(height: 12),
              // Payment Method dropdown
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Payment Method', style: TextStyle(color: Color(0xFF8E8E93), fontSize: 14)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: const Color(0xFF2C2C2E), borderRadius: BorderRadius.circular(8)),
                    child: DropdownButton<String>(
                      value: _selectedPaymentMethod,
                      dropdownColor: const Color(0xFF2C2C2E),
                      underline: const SizedBox(),
                      icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF8E8E93)),
                      items: const [
                        DropdownMenuItem(value: 'Bank', child: Text('Bank', style: TextStyle(color: Colors.white, fontSize: 14))),
                        DropdownMenuItem(value: 'UPI', child: Text('UPI', style: TextStyle(color: Colors.white, fontSize: 14))),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => _selectedPaymentMethod = value);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceOrderButton() {
    return GestureDetector(
      onTap: _amountController.text.isNotEmpty && _priceController.text.isNotEmpty ? _createBuyAd : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: _amountController.text.isNotEmpty && _priceController.text.isNotEmpty ? const Color(0xFF84BD00) : const Color(0xFF2C2C2E),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text('Next Step', textAlign: TextAlign.center, style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
