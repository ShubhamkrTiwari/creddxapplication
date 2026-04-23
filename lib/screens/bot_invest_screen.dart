import 'package:flutter/material.dart';
import '../services/bot_service.dart';

class BotInvestScreen extends StatefulWidget {
  final Map<String, dynamic> strategy;
  final double walletBalance;

  const BotInvestScreen({
    super.key,
    required this.strategy,
    required this.walletBalance,
  });

  @override
  State<BotInvestScreen> createState() => _BotInvestScreenState();
}

class _BotInvestScreenState extends State<BotInvestScreen> {
  final TextEditingController _amountController = TextEditingController();
  bool _isLoading = false;
  double _currentInvestment = 0.0;
  bool _isLoadingInvestment = false;

  @override
  void initState() {
    super.initState();
    _fetchCurrentInvestment();
  }

  Future<void> _fetchCurrentInvestment() async {
    setState(() => _isLoadingInvestment = true);
    try {
      final strategyName = widget.strategy['name']?.toString() ?? '';
      final symbol = widget.strategy['symbol']?.toString() ?? 'BTC-USDT';
      
      final result = await BotService.getUserBotPositions(
        strategy: strategyName,
        symbol: symbol,
      );
      
      if (mounted && result['success'] == true) {
        final data = result['data'];
        final userInvestment = data?['userInvestment'] ?? 0.0;
        setState(() {
          _currentInvestment = userInvestment is double ? userInvestment : double.tryParse(userInvestment.toString()) ?? 0.0;
        });
        debugPrint('Current investment for $strategyName: $_currentInvestment USDT');
      }
    } catch (e) {
      debugPrint('Error fetching current investment: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingInvestment = false);
      }
    }
  }

  Future<void> _handleInvest() async {
    final amount = double.tryParse(_amountController.text);
    debugPrint('=== INVEST HANDLE ===');
    debugPrint('Amount entered: $amount');
    
    if (amount == null || amount <= 0) {
      _showSnackBar('Please enter a valid amount', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final strategyName = widget.strategy['name']?.toString() ?? 'Unknown';
      String botId = strategyName.replaceAll('-', '_').toLowerCase();
      
      debugPrint('Calling BotService.invest with botId: $botId, amount: $amount, strategy: $strategyName');

      final result = await BotService.invest(
        botId: botId,
        amount: amount,
        strategy: strategyName,
      );
      
      debugPrint('Invest API Result: $result');

      if (result['success'] == true) {
        _showSnackBar(result['message'] ?? 'Investment successful!');
        Navigator.pop(context, true);
      } else {
        _showSnackBar(result['error'] ?? 'Investment failed', isError: true);
      }
    } catch (e) {
      debugPrint('Invest Exception: $e');
      _showSnackBar('Investment failed: $e', isError: true);
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
          'Invest in ${widget.strategy['name']?.toString() ?? 'Unknown'}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
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
                  if (_currentInvestment > 0 || _isLoadingInvestment) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF84BD00).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF84BD00).withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.account_balance_wallet,
                            color: Color(0xFF84BD00),
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          if (_isLoadingInvestment)
                            const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF84BD00)),
                              ),
                            )
                          else
                            Text(
                              'Invested: ${_currentInvestment.toStringAsFixed(2)} USDT',
                              style: const TextStyle(
                                color: Color(0xFF84BD00),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
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
                  _buildInfoRow('Strategy', widget.strategy['name']?.toString() ?? 'Unknown'),
                  const SizedBox(height: 8),
                  _buildInfoRow('Annualized ROI', widget.strategy['annualizedROI']?.toString() ?? '0%'),
                  const SizedBox(height: 8),
                  _buildInfoRow('Minimum Invest', 'No minimum'),
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
