import 'dart:async';
import 'package:flutter/material.dart';
import '../services/p2p_service.dart';
import 'p2p_chat_detail_screen.dart';
import 'p2p_place_order_screen.dart';

class P2POrderPaymentMethodScreen extends StatefulWidget {
  final String adId;
  final String orderType;
  final String userName;
  final String price;
  final String available;
  final List<String> paymentMethods;
  final double minLimit;
  final double maxLimit;
  final int payTime;
  final String advertiserId;
  final String quantity;
  final String amount;

  const P2POrderPaymentMethodScreen({
    super.key,
    required this.adId,
    required this.orderType,
    required this.userName,
    required this.price,
    required this.available,
    required this.paymentMethods,
    required this.minLimit,
    required this.maxLimit,
    required this.payTime,
    required this.advertiserId,
    required this.quantity,
    required this.amount,
  });

  @override
  State<P2POrderPaymentMethodScreen> createState() => _P2POrderPaymentMethodScreenState();
}

class _P2POrderPaymentMethodScreenState extends State<P2POrderPaymentMethodScreen> {
  String? _selectedPaymentMethod;
  bool _isLoading = false;
  Timer? _timer;
  int _remainingSeconds = 0;
  bool _isExpired = false;

  @override
  void initState() {
    super.initState();
    _selectedPaymentMethod = widget.paymentMethods.isNotEmpty ? widget.paymentMethods.first : null;
    _startTimer();
  }

  void _startTimer() {
    _remainingSeconds = widget.payTime * 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        setState(() => _isExpired = true);
        timer.cancel();
      }
    });
  }

  String get _formattedTime {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _handlePlaceOrder() async {
    if (_selectedPaymentMethod == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a payment method'), backgroundColor: Colors.red),
      );
      return;
    }

    if (_isExpired) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Time expired. Please go back and try again.'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      int direction = widget.orderType == 'buy' ? 1 : 2;

      final result = await P2PService.placeOrder(
        adId: widget.adId,
        quantity: double.parse(widget.quantity),
        direction: direction,
        payMethod: _selectedPaymentMethod!,
      );

      if (mounted) {
        setState(() => _isLoading = false);
        if (result != null) {
          final orderId = result['data']?['_id'] ?? result['_id'] ?? '';
          final advertiserId = result['data']?['advertiserId'] ?? result['advertiserId'] ?? widget.advertiserId;

          if (widget.orderType == 'buy') {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => P2PPaymentScreen(
                  orderId: orderId,
                  advertiserId: advertiserId,
                  userName: widget.userName,
                  amount: widget.quantity,
                  paymentMethod: _selectedPaymentMethod!,
                ),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Sell order placed successfully!'), backgroundColor: Color(0xFF84BD00)),
            );
            Navigator.popUntil(context, (route) => route.isFirst);
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to place order'), backgroundColor: Colors.red),
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

  void _openChat() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => P2PChatDetailScreen(
          userId: widget.advertiserId,
          userName: widget.userName,
          appealId: '',
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
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
        title: Text(
          '${widget.orderType == 'buy' ? 'Buy' : 'Sell'} USDT',
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat, color: Color(0xFF84BD00)),
            onPressed: _openChat,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF84BD00)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTimerCard(),
                  const SizedBox(height: 20),
                  _buildOrderSummary(),
                  const SizedBox(height: 20),
                  _buildPaymentMethods(),
                  const SizedBox(height: 32),
                  _buildConfirmButton(),
                ],
              ),
            ),
    );
  }

  Widget _buildTimerCard() {
    final isWarning = _remainingSeconds < 300;
    final timerColor = _isExpired ? Colors.red : (isWarning ? Colors.orange : const Color(0xFF84BD00));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: timerColor.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _isExpired ? Icons.timer_off : Icons.timer,
                color: timerColor,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                _isExpired ? 'Time Expired' : 'Time Remaining',
                style: TextStyle(
                  color: timerColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _isExpired ? '00:00' : _formattedTime,
            style: TextStyle(
              color: timerColor,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _isExpired
                ? 'Please go back and try again'
                : 'Complete the order before time runs out',
            style: const TextStyle(
              color: Color(0xFF8E8E93),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderSummary() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Order Summary',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          _buildSummaryRow('Seller', widget.userName),
          const SizedBox(height: 12),
          _buildSummaryRow('Price', '${widget.price} INR'),
          const SizedBox(height: 12),
          _buildSummaryRow('Quantity', '${widget.quantity} USDT'),
          const SizedBox(height: 12),
          _buildSummaryRow('Total Amount', '${widget.amount} INR'),
          const SizedBox(height: 12),
          _buildSummaryRow('Order Type', widget.orderType.toUpperCase()),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF8E8E93),
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentMethods() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Payment Method',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        ...widget.paymentMethods.map((method) => _buildPaymentMethodItem(method)),
      ],
    );
  }

  Widget _buildPaymentMethodItem(String method) {
    final isSelected = _selectedPaymentMethod == method;
    IconData icon;
    switch (method.toLowerCase()) {
      case 'bank transfer':
      case 'bank':
        icon = Icons.account_balance;
        break;
      case 'upi':
        icon = Icons.account_balance_wallet;
        break;
      case 'paytm':
      case 'phonepe':
      case 'google pay':
        icon = Icons.payment;
        break;
      default:
        icon = Icons.payment;
    }

    return GestureDetector(
      onTap: _isExpired ? null : () => setState(() => _selectedPaymentMethod = method),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF84BD00).withOpacity(0.1) : const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF84BD00) : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF84BD00) : const Color(0xFF8E8E93),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                method,
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF8E8E93),
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: Color(0xFF84BD00),
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfirmButton() {
    final canProceed = _selectedPaymentMethod != null && !_isExpired;
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: canProceed ? _handlePlaceOrder : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: canProceed ? const Color(0xFF84BD00) : const Color(0xFF2C2C2E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          _isExpired ? 'Time Expired' : 'Confirm Order',
          style: TextStyle(
            color: canProceed ? Colors.black : const Color(0xFF8E8E93),
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
