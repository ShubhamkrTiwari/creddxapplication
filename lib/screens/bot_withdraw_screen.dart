import 'package:flutter/material.dart';
import '../services/bot_service.dart';
import '../services/socket_service.dart';
import 'dart:async';

class BotWithdrawScreen extends StatefulWidget {
  final Map<String, dynamic> strategy;
  final double investedAmount;

  const BotWithdrawScreen({
    super.key,
    required this.strategy,
    required this.investedAmount,
  });

  @override
  State<BotWithdrawScreen> createState() => _BotWithdrawScreenState();
}

class _BotWithdrawScreenState extends State<BotWithdrawScreen> {
  final TextEditingController _amountController = TextEditingController();
  bool _isLoading = false;
  double _maxWithdrawAmount = 0.0;
  double _currentInvestment = 0.0;
  bool _isLoadingInvestment = false;
  double _liveBotBalance = 0.0;
  StreamSubscription? _balanceSubscription;

  @override
  void initState() {
    super.initState();
    _fetchCurrentInvestment();
    _fetchMaxWithdrawAmount();
    _fetchBotBalance();
    _subscribeToBotBalance();
  }

  @override
  void dispose() {
    _balanceSubscription?.cancel();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _fetchBotBalance() async {
    try {
      final result = await BotService.getBotBalance();
      if (mounted && result['success'] == true && result['data'] != null) {
        final data = result['data'];
        double balance = 0.0;
        if (data['balance'] != null) {
          balance = double.tryParse(data['balance'].toString()) ?? 0.0;
        } else if (data['totalBalance'] != null) {
          balance = double.tryParse(data['totalBalance'].toString()) ?? 0.0;
        } else if (data['availableBalance'] != null) {
          balance = double.tryParse(data['availableBalance'].toString()) ?? 0.0;
        }
        setState(() {
          _liveBotBalance = balance;
        });
      }
    } catch (e) {
      debugPrint('Error fetching bot balance: $e');
    }
  }

  void _subscribeToBotBalance() {
    _balanceSubscription = SocketService.balanceStream.listen((data) {
      if (mounted && (data['type'] == 'wallet_summary_update' || data['type'] == 'wallet_summary')) {
        final balanceData = data['data'];
        if (balanceData != null && balanceData is Map) {
          final botBalance = balanceData['botBalance'] ?? balanceData['bot'];
          if (botBalance != null) {
            double newBalance = 0.0;
            if (botBalance is num) {
              newBalance = botBalance.toDouble();
            } else if (botBalance is Map) {
              newBalance = double.tryParse(botBalance['USDT']?.toString() ?? '0') ?? 0.0;
            }
            setState(() {
              _liveBotBalance = newBalance;
            });
            debugPrint('Withdraw Screen: Bot balance updated: $newBalance');
          }
        }
      }
    });
  }

  Future<void> _fetchMaxWithdrawAmount() async {
    try {
      final result = await BotService.getUserMaxWithdrawAmounts();
      if (mounted && result['success'] == true) {
        final strategyName = widget.strategy['name']?.toString() ?? '';
        double maxAmount = 0.0;
        // Use maxWithdrawOmega for Omega-3X, maxWithdrawAlpha for Alpha-2X
        if (strategyName.toLowerCase().contains('omega')) {
          maxAmount = result['maxWithdrawOmega']?.toDouble() ?? 0.0;
        } else if (strategyName.toLowerCase().contains('alpha')) {
          maxAmount = result['maxWithdrawAlpha']?.toDouble() ?? 0.0;
        }
        // Fallback to invested amount if API returns 0
        if (maxAmount <= 0) {
          maxAmount = widget.investedAmount;
        }
        setState(() {
          _maxWithdrawAmount = maxAmount;
        });
      } else {
        setState(() {
          _maxWithdrawAmount = widget.investedAmount;
        });
      }
    } catch (e) {
      debugPrint('Error fetching max withdraw: $e');
      setState(() {
        _maxWithdrawAmount = widget.investedAmount;
      });
    }
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
        debugPrint('Withdraw - Current investment for $strategyName: $_currentInvestment USDT');
      } else {
        // Fallback to widget value if API fails
        setState(() {
          _currentInvestment = widget.investedAmount;
        });
      }
    } catch (e) {
      debugPrint('Error fetching current investment: $e');
      setState(() {
        _currentInvestment = widget.investedAmount;
      });
    } finally {
      if (mounted) {
        setState(() => _isLoadingInvestment = false);
      }
    }
  }

  Future<void> _handleWithdraw() async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      _showSnackBar('Please enter a valid amount', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final strategyName = widget.strategy['name']?.toString() ?? 'Unknown';
      String botId = strategyName.replaceAll('-', '_').toLowerCase();

      final result = await BotService.withdraw(
        botId: botId,
        amount: amount,
        strategy: strategyName,
      );

      if (result['success'] == true) {
        // Immediately update local balance for instant feedback
        setState(() {
          _liveBotBalance = _liveBotBalance + amount;
        });

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

  void _setMaxAmount() {
    _amountController.text = _maxWithdrawAmount.toStringAsFixed(2);
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
          'Withdraw from ${widget.strategy['name']?.toString() ?? 'Unknown'}',
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_maxWithdrawAmount.toStringAsFixed(2)} USDT',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
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
              child: TextButton.icon(
                onPressed: _setMaxAmount,
                icon: const Icon(Icons.auto_fix_high, color: Colors.orange, size: 18),
                label: const Text(
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
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.orange, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Withdrawal Info',
                          style: TextStyle(
                            color: Colors.orange,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Withdrawal will be processed from your active investment in ${widget.strategy['name']?.toString() ?? 'this strategy'}. Max withdraw: ${_maxWithdrawAmount.toStringAsFixed(2)} USDT',
                          style: const TextStyle(
                            color: Colors.orange,
                            fontSize: 12,
                          ),
                        ),
                      ],
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
                onPressed: _isLoading ? null : _handleWithdraw,
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
      ),
    );
  }
}
