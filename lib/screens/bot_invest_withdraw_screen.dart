import 'package:flutter/material.dart';
import '../services/bot_service.dart';

class BotInvestWithdrawScreen extends StatefulWidget {
  final Map<String, dynamic> strategy;
  final double walletBalance;
  final double investedAmount;
  final int initialTabIndex;

  const BotInvestWithdrawScreen({
    super.key,
    required this.strategy,
    required this.walletBalance,
    required this.investedAmount,
    this.initialTabIndex = 0,
  });

  @override
  State<BotInvestWithdrawScreen> createState() => _BotInvestWithdrawScreenState();
}

class _BotInvestWithdrawScreenState extends State<BotInvestWithdrawScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _amountController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _handleInvest() async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      _showSnackBar('Please enter a valid amount', isError: true);
      return;
    }

    if (amount > widget.walletBalance) {
      _showSnackBar('Maximum invest amount is ${widget.walletBalance.toStringAsFixed(2)} USDT', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      String botId = widget.strategy['name'].replaceAll('-', '_').toLowerCase();

      final result = await BotService.invest(
        botId: botId,
        amount: amount,
        strategy: widget.strategy['name'],
      );

      if (result['success'] == true) {
        _showSnackBar(result['message'] ?? 'Investment successful!');
        Navigator.pop(context, true);
      } else {
        _showSnackBar(result['error'] ?? 'Investment failed', isError: true);
      }
    } catch (e) {
      _showSnackBar('Investment failed: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleWithdraw() async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      _showSnackBar('Please enter a valid amount', isError: true);
      return;
    }

    if (amount > widget.investedAmount) {
      _showSnackBar('Maximum withdrawal amount is ${widget.investedAmount.toStringAsFixed(2)} USDT', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      String botId = widget.strategy['name'].replaceAll('-', '_').toLowerCase();

      final result = await BotService.withdraw(
        botId: botId,
        amount: amount,
        strategy: widget.strategy['name'],
      );

      if (result['success'] == true) {
        _showSnackBar(result['message'] ?? 'Withdrawal successful!');
        Navigator.pop(context, true);
      } else {
        _showSnackBar(result['error'] ?? 'Withdrawal failed', isError: true);
      }
    } catch (e) {
      _showSnackBar('Withdrawal failed: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : const Color(0xFF84BD00),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _setMaxAmount(double amount) {
    _amountController.text = amount.toStringAsFixed(2);
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
          widget.strategy['name'],
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF84BD00),
          labelColor: const Color(0xFF84BD00),
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: 'Invest', icon: Icon(Icons.add_circle_outline)),
            Tab(text: 'Withdraw', icon: Icon(Icons.remove_circle_outline)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildInvestTab(),
          _buildWithdrawTab(),
        ],
      ),
    );
  }

  Widget _buildInvestTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Balance Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF84BD00).withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Available Balance',
                  style: TextStyle(
                    color: Color(0xFF8E8E93),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${widget.walletBalance.toStringAsFixed(2)} USDT',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Amount Input
          const Text(
            'Enter Amount',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFF1C1C1E),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              hintText: 'Enter amount to invest',
              hintStyle: const TextStyle(color: Color(0xFF8E8E93)),
              suffixText: 'USDT',
              suffixStyle: const TextStyle(color: Color(0xFF84BD00)),
            ),
          ),
          const SizedBox(height: 12),

          // Max Button
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => _setMaxAmount(widget.walletBalance),
              child: const Text(
                'Set Max',
                style: TextStyle(color: Color(0xFF84BD00)),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Info Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow('Strategy', widget.strategy['name']),
                const SizedBox(height: 8),
                _buildInfoRow('Annualized ROI', widget.strategy['annualizedROI'] ?? '0%'),
                const SizedBox(height: 8),
                _buildInfoRow('Minimum Invest', '10 USDT'),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Invest Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleInvest,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF84BD00),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                      ),
                    )
                  : const Text(
                      'Invest Now',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWithdrawTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Invested Amount Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.orange.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Invested Amount',
                  style: TextStyle(
                    color: Color(0xFF8E8E93),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${widget.investedAmount.toStringAsFixed(2)} USDT',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Amount Input
          const Text(
            'Enter Amount',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFF1C1C1E),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              hintText: 'Enter amount to withdraw',
              hintStyle: const TextStyle(color: Color(0xFF8E8E93)),
              suffixText: 'USDT',
              suffixStyle: const TextStyle(color: Colors.orange),
            ),
          ),
          const SizedBox(height: 12),

          // Max Button
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => _setMaxAmount(widget.investedAmount),
              child: const Text(
                'Set Max',
                style: TextStyle(color: Colors.orange),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Warning Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.orange.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange, size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Withdrawal will be processed from your active investment in this strategy.',
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Withdraw Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isLoading || widget.investedAmount <= 0 ? null : _handleWithdraw,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
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
                  : const Text(
                      'Withdraw Now',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
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
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
