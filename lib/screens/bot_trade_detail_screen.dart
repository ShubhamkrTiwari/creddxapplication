import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/bot_service.dart';
import '../services/unified_wallet_service.dart';
import 'package_program_screen.dart';

class BotTradeDetailScreen extends StatefulWidget {
  static bool hasPackage = false;
  final String name;
  final String multiplier;

  const BotTradeDetailScreen({
    super.key,
    required this.name,
    required this.multiplier,
  });

  @override
  State<BotTradeDetailScreen> createState() => _BotTradeDetailScreenState();
}

class _BotTradeDetailScreenState extends State<BotTradeDetailScreen> {
  final TextEditingController _investController = TextEditingController();
  final TextEditingController _withdrawController = TextEditingController();
  
  bool _isLoading = true;
  bool _hasPackage = false;
  bool _isInvested = false;
  double _investedAmount = 0.0;
  Map<String, dynamic>? _performanceData;

  @override
  void initState() {
    super.initState();
    _fetchPerformanceData();
    _fetchUserBalanceHistory();
    _checkUserSubscription();
  }

  Future<void> _checkUserSubscription() async {
    try {
      final response = await BotService.getUserSubscription();
      if (mounted && response['success'] == true && response['subscription'] != null) {
        final subscription = response['subscription'];
        final startDate = DateTime.tryParse(subscription['startDate'] ?? '');
        final duration = subscription['duration'] ?? 365;
        
        if (startDate != null) {
          final endDate = startDate.add(Duration(days: duration));
          final now = DateTime.now();
          final daysLeft = endDate.difference(now).inDays;
          
          // Only set _hasPackage if subscription is still active
          if (daysLeft > 0) {
            setState(() {
              _hasPackage = true;
            });
          } else {
            setState(() {
              _hasPackage = false;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking subscription: $e');
    }
  }

  Future<void> _fetchPerformanceData() async {
    setState(() => _isLoading = true);
    try {
      final response = await BotService.getStrategyPerformance(widget.name);
      if (mounted) {
        setState(() {
          if (response['success']) {
            _performanceData = response['data'];
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _fetchUserBalanceHistory() async {
    try {
      final response = await BotService.getBotBalance();
      if (mounted && response['success'] == true) {
        final data = response['data'] ?? {};
        
        // Use exact strategy name mapping to check investment
        String mappedStrategyKey = 'Omega';
        if (widget.name.toLowerCase().contains('omega')) {
          mappedStrategyKey = 'Omega';
        } else if (widget.name.toLowerCase().contains('alpha')) {
          mappedStrategyKey = 'Alpha';
        } else if (widget.name.toLowerCase().contains('ranger')) {
          mappedStrategyKey = 'Ranger';
        } else if (widget.name.toLowerCase().contains('delta')) {
          mappedStrategyKey = 'Delta';
        }

        // Get invested amount for this specific bot from user data
        final userDataResult = await BotService.getUserData();
        if (userDataResult['success'] == true) {
          final userData = userDataResult['data'] ?? {};
          final investments = userData['investments'] as Map<String, dynamic>? ?? {};
          
          double specificInvestment = 0.0;
          investments.forEach((key, value) {
            if (key.toLowerCase().contains(mappedStrategyKey.toLowerCase())) {
              specificInvestment += double.tryParse(value.toString()) ?? 0.0;
            }
          });

          if (specificInvestment > 0) {
            setState(() {
              _investedAmount = specificInvestment;
              _isInvested = true;
            });
          } else {
            setState(() {
              _investedAmount = 0.0;
              _isInvested = false;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching bot balance: $e');
    }
  }

  @override
  void dispose() {
    _investController.dispose();
    _withdrawController.dispose();
    super.dispose();
  }

  void _showAmountDialog({
    required String title, 
    required String hint, 
    required TextEditingController controller, 
    required bool isConfirmingInvestment
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24),
                ),
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: const TextStyle(color: Colors.white38),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: InputBorder.none,
                    suffixIcon: TextButton(
                      onPressed: () {
                        setState(() {
                          controller.text = hint.replaceAll('Max: \$', '').replaceAll('Total: \$', '');
                        });
                      },
                      child: const Text(
                        'Max value',
                        style: TextStyle(color: Color(0xFF4A90E2), fontSize: 14),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white24),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        ),
                        child: const Text('Cancel', style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          if (isConfirmingInvestment) {
                            // Get the investment amount from the controller
                            final amountText = controller.text.trim();
                            final amount = double.tryParse(amountText) ?? 0.0;
                            
                            if (amount > 0) {
                              _makeInvestment(amount);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please enter a valid amount'),
                                  backgroundColor: Colors.red,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          } else {
                            // Logic for withdrawal confirmation
                            final amountText = controller.text.trim();
                            final amount = double.tryParse(amountText) ?? 0.0;
                            
                            if (amount > 0) {
                              _makeWithdrawal(amount);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please enter a valid amount'),
                                  backgroundColor: Colors.red,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF84BD00),
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        ),
                        child: const Text('Confirm', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleInvestClick() {
    if (_hasPackage) {
      _showAmountDialog(
        title: 'Enter Investment Amount',
        hint: 'Max: \$19.00',
        controller: _investController,
        isConfirmingInvestment: true,
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const PackageProgramScreen()),
      ).then((_) {
        _checkUserSubscription();
      }); 
    }
  }

  Future<void> _makeWithdrawal(double amount) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await BotService.withdraw(
        botId: widget.name,
        amount: amount,
        strategy: widget.name,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        if (result['success'] == true) {
          setState(() {
            _isInvested = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Withdrawal successful!'),
              backgroundColor: const Color(0xFF84BD00),
              duration: const Duration(seconds: 3),
            ),
          );
          // Refresh balance via UnifiedWalletService
          UnifiedWalletService.refreshBotBalance();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['error'] ?? 'Withdrawal failed'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _makeInvestment(double amount) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await BotService.invest(
        botId: widget.name,
        amount: amount,
        strategy: widget.name,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        if (result['success'] == true) {
          setState(() {
            _isInvested = true;
            _investedAmount = amount;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Investment successful!'),
              backgroundColor: const Color(0xFF84BD00),
              duration: const Duration(seconds: 3),
            ),
          );
          // Refresh balance via UnifiedWalletService
          UnifiedWalletService.refreshBotBalance();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['error'] ?? 'Investment failed'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '${widget.name}- ${widget.multiplier}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF84BD00)))
        : SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                const Text(
                  'Algo Overview',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                _buildOverviewItem('Pair:', _performanceData?['pair'] ?? 'Multiple Alt Pairs'),
                _buildOverviewItem('AUM:', _performanceData?['aum'] ?? '805.99K'),
                _buildOverviewItem('Volume:', _performanceData?['volume'] ?? 'InfinityM'),
                _buildOverviewItem('Drawdown:', _performanceData?['drawdown'] ?? '172.94%'),
                _buildOverviewItem('Recovery:', _performanceData?['recovery'] ?? '137d Max / 73d Avg'),
                _buildOverviewItem('Trades:', _performanceData?['trades']?.toString() ?? '40'),
                _buildOverviewItem('Win Rate:', _performanceData?['winRate'] ?? '95.00%'),
                _buildOverviewItem('Profit Comm:', _performanceData?['profitComm'] ?? '20%'),
                _buildOverviewItem('Max Risk:', _performanceData?['maxRisk'] ?? '47.20%'),
                
                const SizedBox(height: 40),
                
                const Text(
                  'Performance History',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _buildPerformanceRow('Today', _performanceData?['todayRoi'] ?? '+1.24%', Colors.green),
                _buildPerformanceRow('Last 7 Days', _performanceData?['last7DaysRoi'] ?? '+8.45%', Colors.green),
                _buildPerformanceRow('Last 30 Days', _performanceData?['last30DaysRoi'] ?? '+24.12%', Colors.green),
                _buildPerformanceRow('All Time', _performanceData?['rot'] ?? '+922.19%', Colors.green),
                
                const SizedBox(height: 40),

                const Text(
                  'Strategy Details',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _performanceData?['strategyDescription'] ?? 'This strategy uses multiple indicator confirmations to trade high-volatility altcoin pairs with ${widget.multiplier} leverage. It focuses on momentum breakouts and trend reversals with strict risk management.',
                  style: const TextStyle(
                    color: Color(0xFF8E8E93),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 40),
                
                if (_isInvested) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Invested:',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${_investedAmount.toStringAsFixed(2)} USDT',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                
                Padding(
                  padding: const EdgeInsets.only(bottom: 30.0),
                  child: _isInvested
                    ? Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 56,
                              child: ElevatedButton(
                                onPressed: () => _showAmountDialog(
                                  title: 'Enter Investment Amount',
                                  hint: 'Max: \$1000.00',
                                  controller: _investController,
                                  isConfirmingInvestment: true,
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF84BD00),
                                  foregroundColor: Colors.black,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  'Invest',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SizedBox(
                              height: 56,
                              child: ElevatedButton(
                                onPressed: () => _showAmountDialog(
                                  title: 'Enter Withdrawal Amount',
                                  hint: 'Total: \$${_investedAmount.toStringAsFixed(2)}',
                                  controller: _withdrawController,
                                  isConfirmingInvestment: false,
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF84BD00),
                                  foregroundColor: Colors.black,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  'Withdraw',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _handleInvestClick,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF84BD00),
                            foregroundColor: Colors.black,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Invest',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildOverviewItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF8E8E93),
              fontSize: 15,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF8E8E93),
              fontSize: 15,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
