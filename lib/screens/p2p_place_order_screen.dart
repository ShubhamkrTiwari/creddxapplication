import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/p2p_service.dart';
import 'p2p_chat_detail_screen.dart';

class P2PPlaceOrderScreen extends StatefulWidget {
  final String adId;
  final String orderType; // 'buy' or 'sell'
  final String userName;
  final String price;
  final String available;
  final List<String> paymentMethods;

  const P2PPlaceOrderScreen({
    super.key,
    required this.adId,
    required this.orderType,
    required this.userName,
    required this.price,
    required this.available,
    required this.paymentMethods,
  });

  @override
  State<P2PPlaceOrderScreen> createState() => _P2PPlaceOrderScreenState();
}

class _P2PPlaceOrderScreenState extends State<P2PPlaceOrderScreen> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _depositController = TextEditingController();
  String _selectedPaymentMethod = '';
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedPaymentMethod = widget.paymentMethods.isNotEmpty 
        ? widget.paymentMethods.first 
        : 'Bank';
    _amountController.addListener(_calculateDeposit);
  }

  void _calculateDeposit() {
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    final price = double.tryParse(widget.price) ?? 0.0;
    final deposit = amount * price;
    _depositController.text = deposit.toStringAsFixed(2);
    _validateAmount();
  }

  void _validateAmount() {
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    final price = double.tryParse(widget.price) ?? 0.0;
    final inrValue = amount * price;
    final available = double.tryParse(widget.available) ?? 0.0;
    
    if (inrValue < 150) {
      setState(() => _errorMessage = 'Amount must be at least 150 INR');
    } else if (inrValue > 398) {
      setState(() => _errorMessage = 'Amount must be at most 398 INR');
    } else if (amount > available) {
      setState(() => _errorMessage = 'Amount exceeds available ${widget.available} USDT');
    } else {
      setState(() => _errorMessage = null);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _handlePlaceOrder() async {
    if (_amountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter amount')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Convert order type to direction (1=Buy, 2=Sell)
      int direction = widget.orderType == 'buy' ? 1 : 2;
      
      final result = await P2PService.placeOrder(
        adId: widget.adId,
        quantity: double.tryParse(_amountController.text) ?? 0.0,
        direction: direction,
        payMethod: _selectedPaymentMethod,
      );

      if (mounted) {
        setState(() => _isLoading = false);
        if (result != null) {
          final orderId = result['data']?['_id'] ?? result['_id'] ?? '';
          final advertiserId = result['data']?['advertiserId'] ?? result['advertiserId'] ?? '';

          if (widget.orderType == 'buy') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => P2PPaymentScreen(
                  orderId: orderId,
                  advertiserId: advertiserId,
                  userName: widget.userName,
                  amount: _amountController.text,
                  paymentMethod: _selectedPaymentMethod,
                ),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sell order placed successfully!'), backgroundColor: Color(0xFF84BD00)));
            Navigator.pop(context);
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to place order'), backgroundColor: Colors.red));
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
        title: Text('${widget.orderType == 'buy' ? 'Buy' : 'Sell'} USDT', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
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
                  onChanged: (_) => _validateAmount(),
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
            Text('Price: ${widget.price} INR', style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 12)),
            const Text(' | ', style: TextStyle(color: Color(0xFF8E8E93), fontSize: 12)),
            Text('Limit: 89 - 110 INR', style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 12)),
            const Text(' | ', style: TextStyle(color: Color(0xFF8E8E93), fontSize: 12)),
            Text('Available: ${widget.available}', style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 12)),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Seller Name', style: TextStyle(color: Color(0xFF8E8E93), fontSize: 14)),
                  Text(widget.userName, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(color: Color(0xFF2C2C2E)),
              const SizedBox(height: 12),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Payment Method', style: TextStyle(color: Color(0xFF8E8E93), fontSize: 14)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: const Color(0xFF2C2C2E), borderRadius: BorderRadius.circular(8)),
                    child: DropdownButton<String>(
                      value: _selectedPaymentMethod.isEmpty ? null : _selectedPaymentMethod,
                      dropdownColor: const Color(0xFF2C2C2E),
                      underline: const SizedBox(),
                      icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF8E8E93)),
                      hint: const Text('Select Payment', style: TextStyle(color: Color(0xFF8E8E93), fontSize: 14)),
                      items: widget.paymentMethods.map((method) {
                        return DropdownMenuItem(value: method, child: Text(method, style: const TextStyle(color: Colors.white, fontSize: 14)));
                      }).toList(),
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
      onTap: _errorMessage == null && _amountController.text.isNotEmpty ? _handlePlaceOrder : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: _errorMessage == null && _amountController.text.isNotEmpty ? const Color(0xFF84BD00) : const Color(0xFF2C2C2E),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text('Next Step', textAlign: TextAlign.center, style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class P2PPaymentScreen extends StatefulWidget {
  final String orderId;
  final String advertiserId;
  final String userName;
  final String amount;
  final String paymentMethod;

  const P2PPaymentScreen({
    super.key,
    required this.orderId,
    required this.advertiserId,
    required this.userName,
    required this.amount,
    required this.paymentMethod,
  });

  @override
  State<P2PPaymentScreen> createState() => _P2PPaymentScreenState();
}

class _P2PPaymentScreenState extends State<P2PPaymentScreen> {
  final TextEditingController _utrController = TextEditingController();
  bool _isLoading = false;

  Future<void> _handleConfirmPayment() async {
    if (_utrController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter UTR number')));
      return;
    }

    setState(() => _isLoading = true);
    final success = await P2PService.confirmPayment(widget.orderId, _utrController.text, "");
    
    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment confirmed! waiting for seller to release.'), backgroundColor: Color(0xFF84BD00)));
        Navigator.popUntil(context, (route) => route.isFirst);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to confirm payment'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D), 
        title: const Text('Pay Seller'),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat, color: Color(0xFF84BD00)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => P2PChatDetailScreen(
                    userId: widget.advertiserId,
                    userName: widget.userName,
                    appealId: widget.orderId,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF84BD00)))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text('Scan to Pay', style: TextStyle(color: Colors.white, fontSize: 18)),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                  child: QrImageView(
                    data: 'upi://pay?pa=Ravindersingh1023@oksbi&pn=${widget.userName}&am=${widget.amount}',
                    version: QrVersions.auto,
                    size: 200,
                  ),
                ),
                const SizedBox(height: 24),
                Text('Amount: ${widget.amount} USDT', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                
                // UTR Input
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(12)),
                  child: TextField(
                    controller: _utrController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Enter UTR / Transaction ID',
                      hintStyle: TextStyle(color: Colors.white30),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _handleConfirmPayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF84BD00), 
                    minimumSize: const Size(double.infinity, 54),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('I Have Paid', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                const SizedBox(height: 16),
                
                // Bottom Chat Button
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => P2PChatDetailScreen(
                          userId: widget.advertiserId,
                          userName: widget.userName,
                          appealId: widget.orderId,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.chat, color: Color(0xFF84BD00)),
                  label: const Text('Chat with Seller', style: TextStyle(color: Colors.white)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF1C1C1E)),
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
    );
  }
}
